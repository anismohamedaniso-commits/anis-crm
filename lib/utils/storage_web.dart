// Web implementation using window.localStorage
import 'dart:html' as html;

String? webGet(String key) => html.window.localStorage[key];
void webSet(String key, String value) => html.window.localStorage[key] = value;
void webRemove(String key) => html.window.localStorage.remove(key);
