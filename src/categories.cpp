#include "categories.h"

#include <QHash>
#include <QRegExp>
#include <QSet>

namespace {

struct CategoryKeywords {
    const char *id;
    const char *words;   // space separated, lowercase, English then French
};

// Keywords are matched on whole words, so short ones ("go", "r") are left out
// on purpose: they cost more in false positives than they gain in recall.
const CategoryKeywords KEYWORDS[] = {
    { "code",
      "code coding program programming function class method variable array loop "
      "refactor refactoring syntax compile compiler script api sdk library framework "
      "python javascript typescript java kotlin swift rust golang php ruby perl "
      "cpp qml qtquick html css sql json yaml regex algorithm snippet parser "
      "coder programmation fonction classe methode variable tableau boucle "
      "refactoriser syntaxe compilateur bibliotheque algorithme expression" },

    { "debugging",
      "bug debug debugging error errors exception crash crashed crashing stacktrace "
      "traceback segfault nullpointer failing fails failure broken fix fixing "
      "troubleshoot regression warning stack undefined "
      "erreur erreurs plante plantage corrige corriger reparer panne casse "
      "depannage regression avertissement" },

    { "devops",
      "docker kubernetes container containers deploy deployment deploying pipeline "
      "ansible terraform jenkins nginx apache server servers ssh vpn firewall "
      "systemd cron backup infrastructure cluster proxy dns kernel bash shell "
      "conteneur deploiement serveur serveurs pare sauvegarde noyau" },

    { "data",
      "data dataset database query queries analytics statistics spreadsheet excel "
      "csv pandas numpy dataframe postgres mysql mongodb sqlite schema migration "
      "chart graph visualization machine learning model training inference embedding "
      "donnees base requete requetes analyse statistiques tableur graphique "
      "visualisation apprentissage entrainement" },

    { "design",
      "design ui ux interface mockup wireframe layout typography font fonts palette "
      "colors colour figma sketch icon icons logo branding responsive accessibility "
      "maquette mise typographie police polices couleurs couleur icone icones "
      "charte ergonomie accessibilite" },

    { "writing",
      "write writing rewrite rephrase draft essay article blog post copy copywriting "
      "email letter paragraph sentence grammar spelling proofread summarize summary "
      "tone style newsletter script story novel poem "
      "ecrire ecriture reecrire reformuler redige rediger redaction brouillon essai "
      "lettre courriel paragraphe phrase grammaire orthographe relire relecture "
      "resume resumer nouvelle roman poeme" },

    { "translation",
      "translate translation translating localize localization subtitle subtitles "
      "bilingual dictionary idiom "
      "traduire traduction traduis localisation sous titres bilingue dictionnaire "
      "expression anglais francais espagnol allemand italien portugais" },

    { "learning",
      "explain explanation teach tutorial beginner beginners understand understanding "
      "concept lesson course learn learning revision exam homework exercise "
      "difference between simply "
      "explique expliquer explication apprendre apprentissage cours lecon tutoriel "
      "debutant comprendre comprends notion revision examen devoir exercice" },

    { "research",
      "research compare comparison versus alternatives options review reviews "
      "recommend recommendation benchmark pros cons evaluate best "
      "recherche comparer comparaison alternatives avis recommande recommander "
      "recommandation evaluer meilleur meilleure avantages inconvenients" },

    { "math",
      "math maths mathematics equation equations algebra geometry calculus derivative "
      "integral matrix probability theorem proof formula percentage fraction "
      "mathematiques mathematique equation algebre geometrie derivee integrale "
      "matrice probabilite theoreme demonstration formule pourcentage" },

    { "science",
      "physics chemistry biology astronomy quantum molecule atom cell dna evolution "
      "climate energy experiment scientific universe planet neuron species "
      "physique chimie biologie astronomie molecule atome cellule adn evolution "
      "climat energie experience scientifique univers planete espece" },

    { "business",
      "business startup strategy marketing customer customers client clients sales "
      "product market pricing competitor pitch brand growth saas roadmap stakeholder "
      "entreprise strategie clientele vente ventes produit marche tarification "
      "concurrent concurrence marque croissance" },

    { "finance",
      "money budget invest investment investing stock stocks bond crypto bitcoin "
      "tax taxes salary loan mortgage interest savings insurance accounting invoice "
      "argent budget investir investissement action actions obligation impot impots "
      "salaire pret credit hypotheque interets epargne assurance comptabilite facture" },

    { "career",
      "resume cv cover letter interview job jobs hiring recruiter career promotion "
      "linkedin portfolio internship freelance negotiation onboarding "
      "entretien emploi embauche recruteur recrutement carriere promotion stage "
      "candidature motivation negociation" },

    { "legal",
      "legal law lawyer contract clause gdpr license licensing copyright trademark "
      "patent terms liability compliance regulation lawsuit landlord tenant "
      "juridique loi avocat contrat clause rgpd licence droit auteur brevet "
      "conditions responsabilite conformite reglementation bail locataire proprietaire" },

    { "health",
      "health doctor symptom symptoms pain medicine medication diet nutrition sleep "
      "stress anxiety mental therapy exercise workout fitness muscle calories vitamin "
      "sante medecin symptome symptomes douleur medicament regime nutrition sommeil "
      "stress anxiete mentale therapie sport musculation muscle calories vitamine" },

    { "cooking",
      "recipe recipes cook cooking bake baking oven ingredient ingredients dish meal "
      "sauce dinner lunch breakfast vegetarian vegan dessert pasta bread wine "
      "recette recettes cuisiner cuisine cuire four ingredient ingredients plat repas "
      "sauce diner dejeuner petit vegetarien vegan dessert pates pain vin" },

    { "travel",
      "travel trip flight flights hotel hostel itinerary visa passport airport luggage "
      "destination tourist sightseeing beach city guide backpacking booking "
      "voyage voyager vol vols hotel itineraire visa passeport aeroport bagage "
      "destination touriste plage guide reservation sejour" },

    { "home",
      "furniture apartment house rent moving repair repairing plumbing electricity "
      "garden gardening plant plants paint drill diy renovation cleaning laundry "
      "meuble appartement maison loyer demenagement reparer reparation plomberie "
      "electricite jardin jardinage plante plantes peinture bricolage renovation "
      "menage nettoyage lessive" },

    { "gaming",
      "game games gaming console playstation xbox nintendo steam gamer rpg fps mmo "
      "quest boss speedrun multiplayer mod minecraft "
      "jeu jeux jouer manette console partie personnage quete niveau multijoueur" },

    { "music",
      "music song songs album artist band guitar piano drums chord chords lyrics "
      "melody playlist spotify concert instrument tempo mixing "
      "musique chanson chansons album artiste groupe guitare piano batterie accord "
      "accords paroles melodie concert instrument" },

    { "media",
      "movie movies film films series episode season netflix actor director novel "
      "book books author manga anime comic podcast documentary plot character "
      "cinema serie saison episode acteur realisateur livre livres auteur bande "
      "dessinee podcast documentaire intrigue personnage" },

    { "sports",
      "football soccer basketball tennis running marathon cycling swimming climbing "
      "match tournament league player team score olympics training coach "
      "sport foot basket tennis course marathon velo cyclisme natation escalade "
      "match tournoi championnat joueur equipe score entrainement entraineur" },

    { "relationships",
      "friend friends family relationship partner girlfriend boyfriend wife husband "
      "dating breakup marriage parents children kids conflict apology feelings "
      "advice social lonely "
      "ami amis famille relation copine copain femme mari couple rupture mariage "
      "parents enfants conflit excuses sentiments conseil solitude" },

    { "productivity",
      "productivity organize planning schedule calendar todo task tasks habit habits "
      "routine focus procrastination checklist workflow notes notion obsidian priority "
      "deadline meeting "
      "productivite organiser organisation planning agenda calendrier tache taches "
      "habitude habitudes routine concentration procrastination liste priorite "
      "echeance reunion" },

    { "ideas",
      "brainstorm brainstorming idea ideas name names naming suggest suggestions "
      "creative concept inspiration slogan tagline theme invent imagine "
      "idee idees nom noms nommer suggere suggerer suggestion creatif creative "
      "inspiration slogan concept inventer imaginer trouve" },

    { "practical",
      "how to steps step guide instructions setup install configure settings fix "
      "checklist procedure quickly which choose need help "
      "comment etapes etape guide instructions installer installe configurer "
      "configuration parametres reglage procedure rapidement quel quelle choisir "
      "besoin aide" }
};

const int KEYWORD_COUNT = int(sizeof(KEYWORDS) / sizeof(KEYWORDS[0]));

// Words that appear in almost every prompt; matching them tells us nothing.
QSet<QString> buildStopWords()
{
    return QSet<QString>::fromList(QString(
        "the and for you your with this that have from what when where which "
        "please tell give make want know like just about into over than "
        "les des une pour vous avec dans que qui est sur pas plus mais tout "
        "peux peut fais faire donne dis mon mes ton tes son ses par").split(' '));
}

// Accent-insensitive lowercase word list, so "réponse" matches "reponse".
QStringList normalizedWords(const QString &text)
{
    QString normalized = text.toLower();

    static const char *accented = "àâäáãåçèéêëìíîïñòóôöõùúûüýÿ";
    static const char *plain    = "aaaaaaceeeeiiiinooooouuuuyy";
    const QString from = QString::fromUtf8(accented);
    const QString to = QString::fromLatin1(plain);
    for (int i = 0; i < from.length() && i < to.length(); ++i) {
        normalized.replace(from.at(i), to.at(i));
    }

    return normalized.split(QRegExp("[^a-z0-9]+"), QString::SkipEmptyParts);
}

}

namespace Categories {

QStringList all()
{
    QStringList ids;
    for (int i = 0; i < KEYWORD_COUNT; ++i) {
        ids.append(QString::fromLatin1(KEYWORDS[i].id));
    }
    ids.append("other");
    return ids;
}

bool isValid(const QString &category)
{
    if (category == "other") {
        return true;
    }
    for (int i = 0; i < KEYWORD_COUNT; ++i) {
        if (category == QString::fromLatin1(KEYWORDS[i].id)) {
            return true;
        }
    }
    return false;
}

QString classify(const QString &text)
{
    if (text.trimmed().isEmpty()) {
        return QString();
    }

    // Word -> categories it belongs to, built once.
    static QHash<QString, QStringList> index;
    static QSet<QString> stopWords;
    if (index.isEmpty()) {
        stopWords = buildStopWords();
        for (int i = 0; i < KEYWORD_COUNT; ++i) {
            const QString id = QString::fromLatin1(KEYWORDS[i].id);
            const QStringList words =
                    QString::fromLatin1(KEYWORDS[i].words).split(' ', QString::SkipEmptyParts);
            for (const QString &word : words) {
                if (word.length() < 3 || stopWords.contains(word)) {
                    continue;
                }
                // A word listed in both the English and French halves of the
                // same category must not read as ambiguous evidence.
                if (index[word].contains(id)) {
                    continue;
                }
                index[word].append(id);
            }
        }
    }

    // Only the opening of the message matters: the intent is stated there, and
    // capping the scan keeps this cheap when re-classifying every conversation.
    const QStringList words = normalizedWords(text.left(2000));

    QHash<QString, int> scores;
    QSet<QString> counted;
    for (const QString &word : words) {
        if (word.length() < 3 || counted.contains(word)) {
            continue;
        }
        QHash<QString, QStringList>::const_iterator hit = index.constFind(word);
        if (hit == index.constEnd()) {
            continue;
        }
        counted.insert(word);

        // A word shared by several categories is weaker evidence for each.
        const QStringList &owners = hit.value();
        const int weight = owners.count() == 1 ? 3 : 1;
        for (const QString &id : owners) {
            scores[id] += weight;
        }
    }

    QString best;
    int bestScore = 0;
    for (QHash<QString, int>::const_iterator it = scores.constBegin();
         it != scores.constEnd(); ++it) {
        // Ties resolve alphabetically so the result is stable across runs.
        if (it.value() > bestScore || (it.value() == bestScore && it.key() < best)) {
            bestScore = it.value();
            best = it.key();
        }
    }

    // A single weak hit is noise, not a topic.
    return bestScore >= 3 ? best : QString();
}

}
