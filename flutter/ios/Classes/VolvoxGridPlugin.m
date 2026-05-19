#import "VolvoxGridPlugin.h"

void volvoxgrid_flutter_force_link_symbols(void);

@implementation VolvoxGridPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  volvoxgrid_flutter_force_link_symbols();
}

@end
