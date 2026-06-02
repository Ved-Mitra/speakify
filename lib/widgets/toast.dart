import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT, // Short duration (approx. 2s)
    gravity: ToastGravity.BOTTOM, // Position on screen
    timeInSecForIosWeb: 1, // Duration for iOS/Web
    backgroundColor: Colors.black87,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
