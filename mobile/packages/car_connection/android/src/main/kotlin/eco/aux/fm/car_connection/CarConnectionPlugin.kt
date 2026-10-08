package eco.aux.fm.car_connection

import androidx.car.app.connection.CarConnection
import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Reports the car connection type (0 = none, 1 = Automotive OS, 2 = Android Auto). */
class CarConnectionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var connection: CarConnection? = null
    private var type: Int = CarConnection.CONNECTION_TYPE_NOT_CONNECTED
    private val observer = Observer<Int> { value -> type = value }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "eco.aux.fm/car_connection")
        channel.setMethodCallHandler(this)
        // Plugins attach on the main thread, which observeForever requires.
        connection = CarConnection(binding.applicationContext).also {
            it.type.observeForever(observer)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connectionType" -> result.success(type)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        connection?.type?.removeObserver(observer)
        connection = null
    }
}
