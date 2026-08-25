#pragma once

#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"

class QQmlApplicationEngine;

/// Rewrites qrc:/<path> to qrc:/Custom/<path> whenever the custom resource exists.
/// This is how a custom build replaces an upstream .qml file (here:
/// QGroundControl/FlyView/FlyViewCustomLayer.qml) without editing it.
class CustomQmlOverrideInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    CustomQmlOverrideInterceptor() = default;

    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) final;
};

/*===========================================================================*/

/// Minimal QGCCorePlugin subclass for this overlay.
///
/// It only does two things: register the Custom.EscTelemetry QML module import
/// path and install the resource override interceptor. Every other behavior is
/// inherited from the stock QGCCorePlugin, which keeps upstream updates cheap.
class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit CustomPlugin(QObject *parent = nullptr);
    ~CustomPlugin();

    /// Called by QGCCorePlugin::instance() because CUSTOMCLASS is defined as CustomPlugin.
    static QGCCorePlugin *instance();

    // Overrides from QGCCorePlugin
    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) final;
    void destroyQmlApplicationEngine(QQmlApplicationEngine *qmlEngine) final;

private:
    QQmlApplicationEngine *_qmlEngine = nullptr;
    CustomQmlOverrideInterceptor *_urlInterceptor = nullptr;
};
