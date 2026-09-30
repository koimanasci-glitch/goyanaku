package id.goyana.app;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.ContactsContract;
import android.provider.Settings;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;
import java.util.UUID;

@CapacitorPlugin(name="GoyanaDevice", permissions={
 @Permission(alias="camera", strings={Manifest.permission.CAMERA}),
 @Permission(alias="contacts", strings={Manifest.permission.READ_CONTACTS}),
 @Permission(alias="bluetooth", strings={Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_SCAN}),
 @Permission(alias="location", strings={Manifest.permission.ACCESS_COARSE_LOCATION,Manifest.permission.ACCESS_FINE_LOCATION}),
 @Permission(alias="notifications", strings={Manifest.permission.POST_NOTIFICATIONS})
})
public class GoyanaDevice extends Plugin {
 private BluetoothSocket printer;
 private String printerName="";
 private boolean supported(String alias) {return !((alias.equals("bluetooth")&&Build.VERSION.SDK_INT<31)||(alias.equals("notifications")&&Build.VERSION.SDK_INT<33));}
 private boolean allowed(String alias) {return !supported(alias)||(alias.equals("location")&&androidx.core.content.ContextCompat.checkSelfPermission(getContext(),Manifest.permission.ACCESS_COARSE_LOCATION)==android.content.pm.PackageManager.PERMISSION_GRANTED)||getPermissionState(alias)==PermissionState.GRANTED;}
 @PluginMethod public void requestAccess(PluginCall call) {
  String alias=call.getString("alias", "");
  if(!alias.matches("camera|contacts|bluetooth|location|notifications")){call.reject("Izin tidak dikenal");return;}
  if(allowed(alias)){finishAccess(call);return;}
  requestPermissionForAlias(alias,call,"finishAccess");
 }
 @PermissionCallback private void finishAccess(PluginCall call) {JSObject o=new JSObject();o.put("granted",allowed(call.getString("alias","")));call.resolve(o);}
 @PluginMethod public void permissions(PluginCall call) {JSObject o=new JSObject();for(String a:new String[]{"camera","contacts","bluetooth","location","notifications"})o.put(a,allowed(a)?"granted":getPermissionState(a).toString());call.resolve(o);}
 @PluginMethod public void openSettings(PluginCall call) {getActivity().startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+getContext().getPackageName())));call.resolve();}
 @PluginMethod public void bluetoothSettings(PluginCall call) {getActivity().startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS));call.resolve();}
 @PluginMethod public void loginBar(PluginCall call) {boolean login=call.getBoolean("login",false);getActivity().runOnUiThread(()->{int f=getActivity().getWindow().getDecorView().getSystemUiVisibility();if(login)f|=android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;else f&=~android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;getActivity().getWindow().getDecorView().setSystemUiVisibility(f);call.resolve();});}
 @PluginMethod public void insets(PluginCall call) {JSObject o=new JSObject();int id=getContext().getResources().getIdentifier("status_bar_height","dimen","android");o.put("top",id>0?getContext().getResources().getDimensionPixelSize(id)/getContext().getResources().getDisplayMetrics().density:24);call.resolve(o);}
 @PluginMethod public void contacts(PluginCall call) {
  if(!allowed("contacts")){call.reject("Izin kontak diperlukan");return;}
  new Thread(()->{try {JSArray list=new JSArray();try(Cursor c=getContext().getContentResolver().query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI,new String[]{ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,ContactsContract.CommonDataKinds.Phone.NUMBER},null,null,ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME+" ASC")){if(c!=null)while(c.moveToNext()){JSObject r=new JSObject();r.put("name",c.getString(0));r.put("phone",c.getString(1));list.put(r);}}JSObject o=new JSObject();o.put("contacts",list);call.resolve(o);}catch(Exception e){call.reject("Kontak tidak dapat dibaca",e);}}).start();
 }
 @PluginMethod public void pairedPrinters(PluginCall call) {
  if(!allowed("bluetooth")){call.reject("Izin perangkat sekitar diperlukan");return;}
  try {BluetoothAdapter a=BluetoothAdapter.getDefaultAdapter();if(a==null||!a.isEnabled()){call.reject("Aktifkan Bluetooth HP");return;}JSArray list=new JSArray();for(BluetoothDevice d:a.getBondedDevices()){JSObject r=new JSObject();r.put("name",d.getName()==null?"Perangkat Bluetooth":d.getName());r.put("address",d.getAddress());list.put(r);}JSObject o=new JSObject();o.put("devices",list);call.resolve(o);}catch(Exception e){call.reject("Daftar Bluetooth tidak dapat dibaca",e);}
 }
 @PluginMethod public void connectPrinter(PluginCall call) {
  if(!allowed("bluetooth")){call.reject("Izin perangkat sekitar diperlukan");return;}
  new Thread(()->{BluetoothSocket candidate=null;try {if(printer!=null){printer.close();printer=null;}BluetoothAdapter a=BluetoothAdapter.getDefaultAdapter();BluetoothDevice d=a.getRemoteDevice(call.getString("address",""));a.cancelDiscovery();candidate=d.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"));candidate.connect();printer=candidate;printerName=d.getName();JSObject o=new JSObject();o.put("name",printerName);call.resolve(o);}catch(Exception e){try{if(candidate!=null)candidate.close();}catch(Exception ignored){}call.reject("Gagal menghubungkan printer. Pastikan printer aktif dan sudah dipasangkan di Bluetooth HP.",e);}}).start();
 }
 @PluginMethod public void testPrint(PluginCall call) {new Thread(()->{try{if(printer==null||!printer.isConnected()){call.reject("Hubungkan printer terlebih dahulu");return;}printer.getOutputStream().write(new byte[]{27,64});printer.getOutputStream().write("GOYANA\nTes printer berhasil\n\n\n".getBytes("UTF-8"));printer.getOutputStream().flush();call.resolve();}catch(Exception e){call.reject("Gagal mengirim tes cetak",e);}}).start();}
 @Override protected void handleOnDestroy(){try{if(printer!=null)printer.close();}catch(Exception ignored){}}
}
