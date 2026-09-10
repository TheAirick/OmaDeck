#include "TouchBridge.h"
#include "HostInputGuard.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class OmaDeckTouchPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<TouchBridge>(uri, 1, 0, "TouchBridge");
        qmlRegisterType<HostInputGuard>(uri, 1, 0, "HostInputGuard");
    }
};

#include "TouchPlugin.moc"
