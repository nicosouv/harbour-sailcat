#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QTranslator>
#include <QLocale>

#include "mistralapi.h"
#include "conversationmodel.h"
#include "conversationmanager.h"
#include "settingsmanager.h"
#include "updatechecker.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    app->setOrganizationName("harbour-sailcat");
    app->setApplicationName("SailCat");

    QQuickView *view = SailfishApp::createView();

    // Create translator instance
    QTranslator *translator = new QTranslator(app);

    // Create instances of C++ classes
    MistralAPI mistralApi;
    ConversationManager conversationManager;
    SettingsManager settingsManager;
    UpdateChecker updateChecker;

    // Load initial translation based on settings
    QString language = settingsManager.language();
    QString translationFile = QString("harbour-sailcat-%1").arg(language);
    if (translator->load(translationFile, SailfishApp::pathTo("translations").toLocalFile())) {
        app->installTranslator(translator);
    }

    // Lambda to switch language dynamically
    auto switchLanguage = [app, translator, view](const QString &lang) {
        app->removeTranslator(translator);
        QString translationFile = QString("harbour-sailcat-%1").arg(lang);
        if (translator->load(translationFile, SailfishApp::pathTo("translations").toLocalFile())) {
            app->installTranslator(translator);
        }
        view->engine()->retranslate();
    };

    // Connect language change signal
    QObject::connect(&settingsManager, &SettingsManager::languageChanged, [&settingsManager, switchLanguage]() {
        switchLanguage(settingsManager.language());
    });

    // Expose objects to QML context
    QQmlContext *context = view->rootContext();
    context->setContextProperty("mistralApi", &mistralApi);
    context->setContextProperty("conversationManager", &conversationManager);
    context->setContextProperty("conversationModel", conversationManager.currentConversation());
    context->setContextProperty("settingsManager", &settingsManager);
    context->setContextProperty("updateChecker", &updateChecker);

    // Load main QML
    view->setSource(SailfishApp::pathTo("qml/harbour-sailcat.qml"));
    view->show();

    return app->exec();
}
