from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
root=Path('app/android/app/src/main')
a='{http://schemas.android.com/apk/res/android}'
ET.register_namespace('android','http://schemas.android.com/apk/res/android')
p=root/'AndroidManifest.xml'
tree=ET.parse(p); manifest=tree.getroot()
permissions={
'android.permission.CAMERA':{},'android.permission.READ_CONTACTS':{},
'android.permission.ACCESS_COARSE_LOCATION':{},'android.permission.ACCESS_FINE_LOCATION':{},
'android.permission.BLUETOOTH':{'maxSdkVersion':'30'},'android.permission.BLUETOOTH_ADMIN':{'maxSdkVersion':'30'},
'android.permission.BLUETOOTH_SCAN':{'usesPermissionFlags':'neverForLocation'},'android.permission.BLUETOOTH_CONNECT':{},
'android.permission.POST_NOTIFICATIONS':{},'android.permission.ACCESS_NETWORK_STATE':{}}
for name,attrs in permissions.items():
 if not any(e.get(a+'name')==name for e in manifest.findall('uses-permission')):
  ET.SubElement(manifest,'uses-permission',{a+'name':name,**{a+k:v for k,v in attrs.items()}})
ET.SubElement(manifest,'uses-feature',{a+'name':'android.hardware.camera',a+'required':'false'})
tree.write(p,encoding='utf-8',xml_declaration=True)
for name in ['MainActivity.java','GoyanaDevice.java']:
 shutil.copyfile(Path('native')/name,root/'java/id/goyana/app'/name)
