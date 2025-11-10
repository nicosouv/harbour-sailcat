TARGET = harbour-sailcat

CONFIG += sailfishapp

SOURCES += src/harbour-sailcat.cpp \
    src/mistralapi.cpp \
    src/conversationmodel.cpp \
    src/settingsmanager.cpp \
    src/updatechecker.cpp

HEADERS += src/mistralapi.h \
    src/conversationmodel.h \
    src/settingsmanager.h \
    src/updatechecker.h

DISTFILES += qml/harbour-sailcat.qml \
    qml/cover/CoverPage.qml \
    qml/pages/ChatPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/AboutPage.qml \
    rpm/harbour-sailcat.spec \
    harbour-sailcat.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += translations/harbour-sailcat-fr.ts
