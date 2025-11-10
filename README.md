# SailCat 🐱⛵

<p align="center">
  <img src="icons/172x172/harbour-sailcat.png" alt="SailCat Logo" width="172"/>
</p>

**SailCat** est un client élégant pour **Le Chat de Mistral AI**, spécialement conçu pour **Sailfish OS**. Profitez de conversations intelligentes avec les modèles d'IA les plus avancés de Mistral, directement depuis votre appareil Sailfish.

## ✨ Fonctionnalités

- 🆓 **Support du free tier de Mistral AI** - Commencez gratuitement
- 🔑 **Clé API personnelle** - Utilisez votre propre clé pour un accès illimité
- ⚡ **Streaming en temps réel** - Réponses instantanées et fluides
- 🎨 **Interface native Sailfish** - Intégration parfaite avec Silica
- 💬 **Historique des conversations** - Gardez le contexte de vos échanges
- 🧠 **Choix de modèles** - Mistral Small, Large, ou Pixtral (vision)
- 🌐 **Respecte l'UI/UX Sailfish** - Pulley menu, cover actions, et plus

## 🚀 Installation

### Prérequis

- Sailfish OS 3.0+ ou supérieur
- Connexion Internet
- Clé API Mistral (gratuite sur [console.mistral.ai](https://console.mistral.ai))

### Construction depuis les sources

```bash
# Cloner le repo
git clone https://github.com/nicosouv/harbour-sailcat.git
cd harbour-sailcat

# Compiler avec Sailfish SDK
sfdk build

# Installer le RPM généré
sfdk deploy --manual
```

### Installation du RPM

Téléchargez le fichier `.rpm` depuis les [releases](https://github.com/nicosouv/harbour-sailcat/releases) et installez-le sur votre appareil Sailfish.

## 🔧 Configuration

### Obtenir une clé API Mistral

1. Créez un compte sur [console.mistral.ai](https://console.mistral.ai)
2. Sélectionnez le plan "Experiment" (gratuit)
3. Générez une clé API dans la section "API Keys"
4. Copiez votre clé API

### Configurer SailCat

1. Lancez SailCat
2. Accédez aux **Paramètres** via le pulley menu
3. Activez **"Utiliser ma propre clé API"**
4. Collez votre clé API Mistral
5. Choisissez votre modèle préféré
6. Enregistrez et commencez à chatter !

## 📖 Utilisation

### Démarrer une conversation

1. Ouvrez SailCat
2. Tapez votre message dans le champ de saisie
3. Appuyez sur le bouton d'envoi ou sur Entrée
4. Regardez la réponse apparaître en temps réel grâce au streaming

### Nouvelle conversation

Utilisez le pulley menu et sélectionnez **"Nouvelle conversation"** pour effacer l'historique et recommencer.

### Modèles disponibles

- **Mistral Small** (Recommandé) - Équilibré entre performance et rapidité
- **Mistral Large** - Le plus puissant pour les tâches complexes
- **Pixtral 12B** - Support d'images et vision

## 🏗️ Architecture technique

### Backend Qt C++

- **MistralAPI** - Gestion des requêtes HTTP avec streaming SSE (Server-Sent Events)
- **ConversationModel** - QAbstractListModel pour l'affichage des messages
- **SettingsManager** - Persistance des paramètres avec QSettings

### Frontend QML

- **ChatPage** - Interface principale de conversation avec SilicaListView
- **SettingsPage** - Configuration de l'API et choix du modèle
- **AboutPage** - Informations sur l'application
- **CoverPage** - Couverture active avec statistiques

### Technologies utilisées

- Qt 5.6 (QtCore, QtNetwork, QtQuick, QtQml)
- Sailfish Silica UI Components
- Mistral AI API (REST + Streaming)
- QML + JavaScript pour l'interface

## 🎯 Fonctionnalités de l'API Mistral

### Ce qui est possible

SailCat exploite pleinement les capacités de l'API Mistral :

- **Chat Completions** - Conversations contextuelles
- **Streaming** - Réponses en temps réel (SSE)
- **Modèles multiples** - Accès à Small, Large, et Pixtral
- **Historique** - Gestion manuelle du contexte de conversation
- **Free Tier** - Rate limits adaptés à l'expérimentation

### Endpoint utilisé

```
POST https://api.mistral.ai/v1/chat/completions
```

### Format de requête

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {"role": "user", "content": "Bonjour!"},
    {"role": "assistant", "content": "Bonjour! Comment puis-je vous aider?"}
  ],
  "stream": true
}
```

## 🔒 Sécurité & Confidentialité

- ✅ Les clés API sont stockées localement avec QSettings
- ✅ Pas de télémétrie ou d'analyse
- ✅ Communication directe avec l'API Mistral (HTTPS)
- ✅ Pas de serveur intermédiaire
- ⚠️ Votre clé API donne accès à votre compte Mistral - gardez-la secrète

## 🚀 Releases & CI/CD

SailCat utilise GitHub Actions pour builder et publier automatiquement les releases.

### Build automatique

Chaque tag `vX.Y.Z` déclenche un build multi-architecture :

```bash
git tag v1.0.0
git push origin v1.0.0
```

Le workflow **build-docker.yml** :
- ✅ Build pour armv7hl, aarch64, et i486
- ✅ Génère un changelog depuis les commits
- ✅ Crée une release GitHub avec les RPM
- ✅ Publie automatiquement

Les RPM compilés sont disponibles dans [Releases](https://github.com/nicosouv/harbour-sailcat/releases).

### Validation des PRs

Les Pull Requests sont automatiquement validées avec le workflow **pr-build.yml** qui build pour armv7hl.

### Pour les mainteneurs

Voir [RELEASE.md](RELEASE.md) pour le guide complet de release.

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment participer :

1. Fork le projet
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📝 TODO / Roadmap

- [ ] Support d'images avec Pixtral (upload depuis la galerie)
- [ ] Sauvegarde persistante des conversations
- [ ] Export des conversations (texte, markdown)
- [ ] Support de plusieurs conversations simultanées
- [ ] Paramètres avancés (température, max_tokens)
- [ ] Traductions (anglais, finnois, etc.)
- [ ] Thèmes de couleurs personnalisés
- [ ] Support des agents Mistral

## 🐛 Problèmes connus

- Les rate limits du free tier peuvent être restrictifs pour un usage intensif
- Le streaming peut parfois être lent selon la connexion réseau
- Pas de support hors-ligne (nécessite une connexion Internet)

## 📄 Licence

MIT License - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- **Mistral AI** pour leur excellente API et leur free tier généreux
- **Jolla** pour Sailfish OS et le framework Silica
- **La communauté Sailfish** pour leur support et leurs retours

## 📧 Contact

Nicolas Souv - [@nicosouv](https://github.com/nicosouv)

Lien du projet: [https://github.com/nicosouv/harbour-sailcat](https://github.com/nicosouv/harbour-sailcat)

---

<p align="center">
  Fait avec ❤️ pour Sailfish OS
</p>
