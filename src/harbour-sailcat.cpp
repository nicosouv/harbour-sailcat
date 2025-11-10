#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>

#include "mistralapi.h"
#include "conversationmodel.h"
#include "settingsmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    app->setOrganizationName("harbour-sailcat");
    app->setApplicationName("SailCat");

    QQuickView *view = SailfishApp::createView();

    // Créer les instances des classes C++
    MistralAPI mistralApi;
    ConversationModel conversationModel;
    SettingsManager settingsManager;

    // Exposer les objets au contexte QML
    QQmlContext *context = view->rootContext();
    context->setContextProperty("mistralApi", &mistralApi);
    context->setContextProperty("conversationModel", &conversationModel);
    context->setContextProperty("settingsManager", &settingsManager);

    // Charger le QML principal
    view->setSource(SailfishApp::pathTo("qml/harbour-sailcat.qml"));
    view->show();

    return app->exec();
}
