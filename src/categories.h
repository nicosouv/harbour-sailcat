#ifndef CATEGORIES_H
#define CATEGORIES_H

#include <QString>
#include <QStringList>

// Conversation topic labels. The model is asked to pick one; when it refuses,
// answers something unknown or falls back to "other", a local keyword
// heuristic has a second go so conversations do not all end up as "other".
namespace Categories {

// Every valid identifier, "other" last.
QStringList all();

bool isValid(const QString &category);

// Best guess from raw text, or an empty string when nothing scores.
// Never returns "other": an empty result lets the caller decide.
QString classify(const QString &text);

}

#endif // CATEGORIES_H
