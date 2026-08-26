#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTranslator>
#include <QLocale>

#include "mistralapi.h"
#include "conversationmodel.h"
#include "conversationmanager.h"
#include "providers.h"
#include "settingsmanager.h"

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

    // The manager owns the streaming lifecycle so an answer survives the chat
    // page being popped off the stack mid-response.
    conversationManager.bindApi(&mistralApi);

    // The API layer follows the conversation on screen from here rather than
    // from QML: a page that forgot to reconfigure it would send the
    // conversation to the wrong endpoint, with the wrong key. A conversation is
    // pinned to its own provider, so this is not necessarily the selected one.
    auto applyProvider = [&mistralApi, &settingsManager, &conversationManager]() {
        const QString providerId = conversationManager.currentProviderId();
        const Providers::Provider provider = Providers::byId(providerId);
        mistralApi.setEndpoint(providerId,
                               settingsManager.baseUrlFor(providerId),
                               provider.modelSource,
                               provider.streamUsageOption,
                               provider.keyRequired);
    };

    // The default only decides what a new conversation starts with.
    conversationManager.setDefaultProvider(settingsManager.providerId());
    applyProvider();

    QObject::connect(&settingsManager, &SettingsManager::providerChanged,
                     [&settingsManager, &conversationManager, applyProvider]() {
        conversationManager.setDefaultProvider(settingsManager.providerId());
        applyProvider();
    });
    QObject::connect(&conversationManager,
                     &ConversationManager::currentProviderIdChanged, applyProvider);

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
        // Reload the QML to apply translations
        QUrl source = view->source();
        view->engine()->clearComponentCache();
        view->setSource(QUrl());
        view->setSource(source);
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

    // Load main QML
    view->setSource(SailfishApp::pathTo("qml/harbour-sailcat.qml"));
    view->show();

    return app->exec();
}
