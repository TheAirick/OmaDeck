#include "TouchBridge.h"

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
    }
};

#include "TouchPlugin.moc"
