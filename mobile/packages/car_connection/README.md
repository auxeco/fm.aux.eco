# car_connection

Local plugin for AUX FM. Wraps AndroidX
[`CarConnection`](https://developer.android.com/training/cars/apps/library/connection-api)
so the app can tell whether the phone is connected to Android Auto. It is
registered on every Flutter engine, including the one Android Auto starts
without the main activity.

Other platforms report "not connected".
