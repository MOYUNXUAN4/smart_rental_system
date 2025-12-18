package com.example.smart_rental_system

// 👇 关键就是这一行，刚才报错就是因为缺了它或者写错了
import io.flutter.embedding.android.FlutterFragmentActivity

// 👇 这里的类名必须继承 FlutterFragmentActivity
class MainActivity: FlutterFragmentActivity() {
}