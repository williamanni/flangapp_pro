//package pro.flangapp.app.flangapp_pro
//
//import com.onesignal.notifications.IActionButton
//import com.onesignal.notifications.IDisplayableMutableNotification
//import com.onesignal.notifications.INotificationReceivedEvent
//import com.onesignal.notifications.INotificationServiceExtension
//import androidx.annotation.Keep
//
//@Keep // Keep is required to prevent minification from renaming or removing your class
//class NotificationServiceExtension : INotificationServiceExtension {
//    override fun onNotificationReceived(event: INotificationReceivedEvent) {
//        val x: Int = 2
//        //val notification: IDisplayableMutableNotification = event.getNotification()
//
//        // this is an example of how to modify the notification by changing the background color to blue
//        //notification.setExtender { builder -> builder.setColor(-0xffff01) }
//
//        //If you need to perform an async action or stop the payload from being shown automatically,
//        //use event.preventDefault(). Using event.notification.display() will show this message again.
//    }
//}