# Architecture de SailCat

Ce document décrit l'architecture technique de SailCat, une application Sailfish OS pour Le Chat de Mistral AI.

## Vue d'ensemble

SailCat est une application native Sailfish OS construite avec Qt 5.6 et QML. Elle utilise l'API REST de Mistral AI avec support du streaming (Server-Sent Events) pour offrir des conversations en temps réel.

```
┌─────────────────────────────────────────────┐
│           Interface QML (Silica)             │
│  ┌──────────┬──────────┬──────────────────┐ │
│  │ChatPage  │Settings  │  AboutPage       │ │
│  │          │Page      │                  │ │
│  └──────────┴──────────┴──────────────────┘ │
└──────────────────┬──────────────────────────┘
                   │ Qt/QML Context Properties
┌──────────────────┴──────────────────────────┐
│         Backend Qt C++ (QtCore/QtNetwork)    │
│  ┌──────────┬─────────────┬───────────────┐ │
│  │MistralAPI│Conversation │  Settings     │ │
│  │          │Model        │  Manager      │ │
│  └──────────┴─────────────┴───────────────┘ │
└──────────────────┬──────────────────────────┘
                   │ HTTPS/SSE
┌──────────────────┴──────────────────────────┐
│         Mistral AI API                       │
│    https://api.mistral.ai/v1/                │
└──────────────────────────────────────────────┘
```

## Composants principaux

### 1. Backend C++ (`src/`)

#### MistralAPI (`mistralapi.h/cpp`)

**Responsabilité**: Gestion de la communication avec l'API Mistral AI.

**Fonctionnalités**:
- Envoi de requêtes POST vers `/v1/chat/completions`
- Support du streaming via Server-Sent Events (SSE)
- Parsing des événements SSE en temps réel
- Gestion des erreurs réseau et API
- Annulation des requêtes en cours

**Signaux Qt**:
- `streamingResponse(QString)` - Émis pour chaque chunk de texte reçu
- `responseCompleted()` - Émis quand la réponse est complète
- `messageSent()` - Émis quand la requête est envoyée
- `errorChanged()` - Émis en cas d'erreur

**Propriétés Q_PROPERTY**:
- `isBusy` - Indique si une requête est en cours
- `error` - Message d'erreur actuel

**Implémentation clé**:
```cpp
void MistralAPI::parseStreamLine(const QString &line) {
    // Format SSE: "data: {json}"
    // Extraction du delta.content de la réponse JSON
    // Émission du signal streamingResponse
}
```

#### ConversationModel (`conversationmodel.h/cpp`)

**Responsabilité**: Modèle de données pour l'historique des conversations.

**Type**: `QAbstractListModel` - Compatible avec QML ListView

**Structure de données**:
```cpp
struct Message {
    QString role;      // "user" ou "assistant"
    QString content;   // Contenu du message
    qint64 timestamp;  // Horodatage Unix
};
```

**Rôles QML**:
- `role` - Rôle du message (user/assistant)
- `content` - Contenu textuel
- `timestamp` - Horodatage

**Méthodes Q_INVOKABLE**:
- `addUserMessage(QString)` - Ajouter un message utilisateur
- `addAssistantMessage(QString)` - Ajouter une réponse de l'assistant
- `updateLastAssistantMessage(QString)` - Mettre à jour pendant le streaming
- `clearConversation()` - Effacer l'historique
- `toJsonArray()` - Convertir en format JSON pour l'API

**Comportement de streaming**:
La méthode `updateLastAssistantMessage()` permet d'afficher progressivement la réponse de l'IA en mettant à jour le dernier message au fur et à mesure que les chunks arrivent.

#### SettingsManager (`settingsmanager.h/cpp`)

**Responsabilité**: Gestion persistante des paramètres utilisateur.

**Stockage**: `QSettings` (fichiers de configuration locaux)

**Propriétés Q_PROPERTY**:
- `apiKey` - Clé API Mistral de l'utilisateur
- `modelName` - Modèle sélectionné (mistral-small-latest, etc.)
- `useCustomKey` - Utiliser une clé personnelle ou le free tier

**Méthodes Q_INVOKABLE**:
- `availableModels()` - Liste des modèles disponibles
- `clearApiKey()` - Supprimer la clé API
- `hasApiKey()` - Vérifier si une clé est configurée

**Persistance**:
Les paramètres sont sauvegardés automatiquement à chaque modification dans:
```
~/.config/harbour-sailcat/SailCat.conf
```

### 2. Frontend QML (`qml/`)

#### ChatPage.qml

**Responsabilité**: Interface principale de conversation.

**Composants Silica**:
- `SilicaFlickable` - Conteneur scrollable
- `PullDownMenu` - Menu pour paramètres/nouvelle conversation
- `SilicaListView` - Affichage des messages
- `TextField` + `IconButton` - Saisie de messages

**Layout des messages**:
```qml
Rectangle {
    anchors.left: role === "user" ? parent.left : undefined
    anchors.right: role === "assistant" ? parent.right : undefined
    // Messages utilisateur à gauche, assistant à droite
}
```

**Gestion du streaming**:
```qml
property string streamingContent: ""

Connections {
    target: mistralApi
    onStreamingResponse: {
        streamingContent += content
        conversationModel.updateLastAssistantMessage(streamingContent)
    }
}
```

**Comportement**:
1. L'utilisateur tape un message et appuie sur Envoyer
2. Le message est ajouté au `conversationModel`
3. Un message vide de l'assistant est créé
4. L'API est appelée avec `mistralApi.sendMessage()`
5. Les chunks de réponse sont accumulés dans `streamingContent`
6. Le dernier message est mis à jour en temps réel
7. Quand la réponse est complète, `streamingContent` est réinitialisé

#### SettingsPage.qml

**Responsabilité**: Configuration de l'API et des préférences.

**Type**: `Dialog` - Permet d'accepter ou annuler les modifications

**Composants**:
- `TextSwitch` - Activer/désactiver clé personnelle
- `TextField` - Saisie de la clé API
- `ComboBox` - Sélection du modèle
- `Button` - Effacer la clé API

**Validation**:
```qml
canAccept: apiKeyField.text.trim().length > 0 || !useCustomKeySwitch.checked
```

**Sauvegarde**:
Les modifications sont appliquées uniquement si l'utilisateur accepte le dialog (bouton "Enregistrer").

#### AboutPage.qml

**Responsabilité**: Informations sur l'application.

**Contenu**:
- Version de l'application
- Description et fonctionnalités
- Crédits et licence
- Lien vers le code source GitHub

#### CoverPage.qml

**Responsabilité**: Affichage sur la couverture active (écran d'accueil).

**Affichage**:
- Icône de l'application
- Nom "SailCat"
- Nombre de messages dans la conversation

**Cover Actions**:
- Action "Nouveau" pour effacer la conversation

### 3. Point d'entrée (`src/harbour-sailcat.cpp`)

**Responsabilité**: Initialisation de l'application Qt/Sailfish.

**Processus de démarrage**:
1. Création de `QGuiApplication`
2. Configuration de l'organisation et du nom d'application
3. Création de `QQuickView` pour le rendu QML
4. Instanciation des objets C++ (API, Model, Settings)
5. Exposition au contexte QML via `setContextProperty`
6. Chargement du QML principal
7. Affichage de la fenêtre
8. Lancement de la boucle d'événements Qt

**Context Properties**:
```cpp
context->setContextProperty("mistralApi", &mistralApi);
context->setContextProperty("conversationModel", &conversationModel);
context->setContextProperty("settingsManager", &settingsManager);
```

Ces objets deviennent des variables globales accessibles depuis n'importe quel fichier QML.

## Flux de données

### Envoi d'un message

```
User Input (QML TextField)
    ↓
ChatPage.sendMessage()
    ↓
conversationModel.addUserMessage()
    ↓
conversationModel.addAssistantMessage("") // Message vide
    ↓
mistralApi.sendMessage(apiKey, model, messages)
    ↓
QNetworkAccessManager.post()
    ↓
[Réseau] → Mistral API
```

### Réception de la réponse (Streaming)

```
[Réseau] ← Mistral API (SSE)
    ↓
QNetworkReply.readyRead()
    ↓
MistralAPI.onReadyRead()
    ↓
MistralAPI.processStreamData()
    ↓
MistralAPI.parseStreamLine()
    ↓
emit streamingResponse(content)
    ↓
[Signal Qt] → QML Connections
    ↓
streamingContent += content
    ↓
conversationModel.updateLastAssistantMessage()
    ↓
[Binding Qt] → ListView update
    ↓
UI mis à jour en temps réel
```

## Format de l'API Mistral

### Requête

```http
POST https://api.mistral.ai/v1/chat/completions
Content-Type: application/json
Authorization: Bearer <API_KEY>
Accept: text/event-stream
```

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {"role": "user", "content": "Bonjour"},
    {"role": "assistant", "content": "Bonjour! Comment puis-je vous aider?"},
    {"role": "user", "content": "Quel temps fait-il?"}
  ],
  "stream": true
}
```

### Réponse (Streaming SSE)

```
data: {"choices":[{"delta":{"role":"assistant"}}]}

data: {"choices":[{"delta":{"content":"Il"}}]}

data: {"choices":[{"delta":{"content":" fait"}}]}

data: {"choices":[{"delta":{"content":" beau"}}]}

data: [DONE]
```

## Gestion des erreurs

### Erreurs réseau
- Timeout de connexion
- Perte de connexion
- Serveur inaccessible

→ Affichées via `mistralApi.error` dans un `Label` rouge sur `ChatPage`

### Erreurs API
- Clé API invalide (401)
- Rate limit dépassé (429)
- Modèle invalide (400)

→ Parsing du JSON d'erreur et extraction du message détaillé

### Erreurs utilisateur
- Clé API manquante
- Champ de message vide

→ Validation côté QML (boutons désactivés, redirections)

## Sécurité

### Stockage de la clé API

```cpp
QSettings m_settings("harbour-sailcat", "SailCat");
m_settings.setValue("apiKey", m_apiKey);
```

- Stockage local uniquement (pas de cloud)
- Lecture/écriture protégées par permissions Linux
- Pas de transmission à des tiers
- Communication HTTPS uniquement avec Mistral

### Bonnes pratiques

- ✅ Validation des entrées utilisateur
- ✅ Gestion des erreurs réseau
- ✅ Pas de hardcoding de secrets
- ✅ Utilisation de HTTPS
- ✅ Respect du rate limiting

## Build & Packaging

### Compilation

```bash
qmake5 harbour-sailcat.pro
make
```

### Packaging RPM

Le fichier `harbour-sailcat.spec` définit:
- Dépendances (`sailfishsilica-qt5`, Qt5 modules)
- Processus de build (`%qmake5`, `make`)
- Installation (`%qmake5_install`)
- Fichiers inclus dans le RPM

### Structure du RPM

```
/usr/bin/harbour-sailcat                      # Exécutable
/usr/share/harbour-sailcat/qml/               # Fichiers QML
/usr/share/applications/harbour-sailcat.desktop
/usr/share/icons/hicolor/*/apps/harbour-sailcat.png
```

## Performance

### Optimisations

- **Lazy loading**: ListView charge les items à la demande
- **Streaming**: Affichage progressif sans attendre la réponse complète
- **Modèle C++**: QAbstractListModel performant pour grandes listes
- **Bindings efficaces**: Mise à jour uniquement des items modifiés

### Considérations

- Le streaming réduit la latence perçue
- Le buffer SSE évite les pertes de données
- Les signaux Qt sont thread-safe
- QML est optimisé pour l'affichage en liste

## Extensions futures

### Support d'images (Pixtral)

Nécessiterait:
- `QtMultimedia` pour capturer/sélectionner images
- Encodage base64 des images
- Format de message enrichi dans l'API

### Persistance des conversations

Implémentation possible:
- Sauvegarde JSON dans `~/.local/share/harbour-sailcat/`
- Load/Save via `SettingsManager`
- Liste des conversations avec timestamps

### Agents Mistral

L'API Agents offre:
- Mémoire automatique des conversations
- Pas besoin de gérer l'historique manuellement
- Endpoint `/v1/agents/` au lieu de `/chat/completions`

## Références

- [Mistral API Docs](https://docs.mistral.ai/api)
- [Sailfish SDK Docs](https://docs.sailfishos.org/)
- [Qt 5.6 Documentation](https://doc.qt.io/qt-5.6/)
- [Silica Components](https://sailfishos.org/develop/docs/silica/)
