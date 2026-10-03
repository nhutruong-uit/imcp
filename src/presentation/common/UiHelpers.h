#pragma once

#include "domain/entities/Language.h"

#include <QString>

class QAbstractItemModel;
class QComboBox;
class QFrame;
class QLabel;
class QPushButton;
class QWidget;

// Small building blocks shared by the pages, so every screen looks and behaves the same
namespace UiHelpers {
QPushButton* primaryButton(const QString& text, const QString& icon, QWidget* parent); // filled accent button
QPushButton* secondaryButton(const QString& text, const QString& icon, QWidget* parent); // outlined button
QLabel* pageTitle(const QString& text, QWidget* parent);
QFrame* card(QWidget* parent);
void showError(QWidget* parent, const QString& message); // warning box with the (translated) error
bool confirm(QWidget* parent, const QString& question);  // Yes/No box, "No" by default; true = Yes
// File dialog, then export the model to CSV/PDF
void exportCsv(QWidget* parent, const QAbstractItemModel& model, const QString& suggestedName);
void exportPdf(QWidget* parent, const QAbstractItemModel& model, const QString& title,
               const QString& preparedBy);
// Language picker (object name "languageCombo"); item data = language code ("vi", "en")
QComboBox* languageSelector(Language current, QWidget* parent);
} // namespace UiHelpers
