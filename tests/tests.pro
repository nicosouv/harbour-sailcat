TEMPLATE = app
TARGET = tst_sailcat

QT += core network gui testlib
CONFIG += c++11 console
CONFIG -= app_bundle

INCLUDEPATH += ../src

SOURCES += tst_main.cpp \
    ../src/conversationmodel.cpp \
    ../src/conversationmanager.cpp \
    ../src/mistralapi.cpp \
    ../src/settingsmanager.cpp \
    ../src/securestore.cpp \
    ../src/categories.cpp

HEADERS += ../src/conversationmodel.h \
    ../src/conversationmanager.h \
    ../src/mistralapi.h \
    ../src/settingsmanager.h \
    ../src/securestore.h \
    ../src/categories.h
