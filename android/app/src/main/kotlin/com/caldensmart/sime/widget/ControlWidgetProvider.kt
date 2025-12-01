// package com.caldensmart.sime.widget

// import android.appwidget.AppWidgetManager
// import android.content.Context
// import android.content.SharedPreferences
// import es.antonborri.home_widget.HomeWidgetProvider

// class ControlWidgetProvider : HomeWidgetProvider() {

//     // Implementamos onUpdate porque es obligatorio (para que compile)
//     override fun onUpdate(
//         context: Context,
//         appWidgetManager: AppWidgetManager,
//         appWidgetIds: IntArray,
//         widgetData: SharedPreferences
//     ) {
//         // ¡LO DEJAMOS VACÍO INTENCIONALMENTE!
//         // No hacemos nada aquí para evitar sobrescribir el widget con una vista vacía.
//         // Esperamos a que Flutter envíe la foto mediante HomeWidget.updateWidget.
//     }
// }