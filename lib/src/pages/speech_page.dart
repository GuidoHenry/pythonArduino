import 'dart:typed_data';

//ESTILO BOTON
import 'package:avatar_glow/avatar_glow.dart';

//ESTILOS
import 'package:espich_app/constants.dart';
import 'package:espich_app/src/data.dart';
import 'package:espich_app/src/widgets/custom_shape_clipper.dart';
import 'package:flutter/material.dart';
import 'package:highlight_text/highlight_text.dart';

//LIBRERIA DE VOZ A TEXTO
import 'package:speech_to_text/speech_to_text.dart';

//LIBRERIA DE CONEXION BT
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class SpeechPage extends StatefulWidget {
  @override
  _SpeechPageState createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;
  double _voiceVolume = 0.0;
  BluetoothConnection _bluetoothConnection;
  bool _connected;

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
    _connected = false;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Column(
        children: [
          //Fondo Gradiente superior
          Stack(
            children: [
              ClipPath(
                clipper: CustomShapeClipper(),
                child: Container(
                  height: size.height * .3,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.cyanAccent],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: Text(
                        'Presiona el botón y empieza a hablar ...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      )),
                    ),
                  ),
                ),
              ),
            ],
          ),
          //Si ya dictamos el texto mostramos la PRECISION de la escucha
          buildRowPrecision(),
          // Si ya dictamos el texto, mostramos el texto
          Container(
              height: size.height * .42,
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: ListView(
                physics: BouncingScrollPhysics(),
                children: [
                  // Si el texto NO es vacio, muestro el texto. SINO muestro el icono del microfono.
                  _text.isNotEmpty  ? buildCardText() : Center(
                          child: Text(
                          '🎤',
                          textScaleFactor: 3,
                        )),
                ],
              )),
          //DIVISOR
          Expanded(child: Divider(),),
          // Icono de escucha mientras dictamos
          buildVoiceSpectrum(),
          // FILA DE BOTONES
          buildFloatingButtons(),
        ],
      ),
    );
  }

  Row buildRowPrecision() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
            child: Divider(
          indent: 10,
          endIndent: 10,
        )),
        Text('Precisión: ${(_confidence * 100).toStringAsFixed(1)}%'),
        Expanded(
          child: Divider(
            indent: 10,
            endIndent: 10,
          ),
        )
      ],
    );
  }

  Row buildFloatingButtons() {
    //FILA
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        //BOTON ESCUCHAR
        AvatarGlow(
          animate: _isListening,
          glowColor: Colors.blue[600],
          endRadius: 50,
          duration: Duration(seconds: 2),
          repeat: true,
          repeatPauseDuration: Duration(milliseconds: 100),
          child: FloatingActionButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
        ),
        //BOTON ENVIAR TEXTO
        FloatingActionButton(
            mini: false,
            backgroundColor:
                (this._connected == true) ? Colors.amberAccent : Colors.grey,
            tooltip: 'Enviar a la pantalla',
            onPressed: () => sendText(),
            child: Icon(Icons.send)),
        //BOTON CONECTAR BT
        FloatingActionButton(
            mini: false,
            backgroundColor:
                (this._connected == true) ? Colors.grey : Colors.green,
            tooltip: 'CONECTAR Bluetooth',
            onPressed: () => connectBT(),
            child: Icon(Icons.sensors)),
        // BOTON DESCONECTAR BT
        FloatingActionButton(
            mini: false,
            backgroundColor:
                (this._connected == true) ? Colors.red : Colors.grey,
            tooltip: 'DESCONECTAR Bluetooth',
            onPressed: () => disconnectBT(),
            child: Icon(Icons.sensors_off)),
      ],
    );
  }

  Padding buildVoiceSpectrum() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          curve: Curves.ease,
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
            Constants.secondaryColor,
            Constants.primaryLightColor,
            Constants.primaryColor
          ])),
          height: 10,
          width: _voiceVolume == 0 ? 10 : _voiceVolume * 10,
        ),
      ),
    );
  }

  Card buildCardText() {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextHighlight(
          text: _text,
          textAlign: TextAlign.center,
          words: highlights,
          textStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              color: Colors.black,
              height: 1.2),
        ),
      ),
    );
  }

  void _listen() async {
    //Evaluamos si estamos ya escuchando
    if (!_isListening) {
      //NO ESTAMOS ESCUCHANDO
      //seteamos la variable "available" en TRUE si el microfono esta funcionando y tenemos los permisos
      // adecuados y seteamos la variable en FALSE si el mifrono NO esta funcionando
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );

      //evaluamos si es el microfono funciona
      if (available) {
        //MICROFONO FUNCIONA
        //Seteamos la variable _isListening en TRUE (estamos en proceso de escucha)
        setState(() => _isListening = true);
        //llamamos a la libreria para escuchar
        _speech.listen(
          onResult: (result) => setState(() {
            //el resultado de la escucha la transformamos en TEXTO.
            _text = result.recognizedWords;

            //Si el resultado tiene confianza y la confianza es mayor a 0
            if (result.hasConfidenceRating && result.confidence > 0) {
              //seteamos el valor de la confianza para mostrarlo en pantalla
              _confidence = result.confidence;
              //y dejamos de escuchar
              _isListening = false;
              _voiceVolume = 0;
            }
          }),
          listenMode: ListenMode.dictation,
          onSoundLevelChange: (level) {
            setState(() => _voiceVolume = level > 1 ? level : 1);
          },
        );
      }
    } else {
      //SI EL MICROFONO NO ESTA DISPONIBLE
      //Seteamos la variable de escucha en FALSO.
      setState(() => _isListening = false);
      _voiceVolume = 0;
      //Llamamos a la libreria para indicarle que detenga la escucha
      _speech.stop();
    }
  }

  void sendText() async {
    try {
      //Convertimos el texto que esta en la variable _text que ingreso por el microfono
      // a Uint8List para poder enviarlo
      Uint8List outputAsUint8List = new Uint8List.fromList(this._text.codeUnits);
      //enviamos el Uint8List por BT
      this._bluetoothConnection.output.add(outputAsUint8List);
      print(this._text.length);
    } catch (exception) {
      print('Cannot connect, exception occured');
    }
  }

  void connectBT() async {
    //Definimos la MAC del Modulo BT del Arduino
    String address = '00:19:09:01:1D:9A';
    //Nos conectamos a la direccion definida
    this._bluetoothConnection = await BluetoothConnection.toAddress(address);
    //Definimos el comando a enviar al Arduino
    String connect = "Conectar";
    //convertimos de texto a Uint8List el comando para poder enviarlo
    Uint8List outputAsUint8List = new Uint8List.fromList(connect.codeUnits);
    //Enviamos el comando "Conectar" en formato Uint8List
    await this._bluetoothConnection.output.add(outputAsUint8List);
    //seteamos el estado del Widget en CONECTADO true.
    setState(() {
      this._connected = true;
    });
  }

  void disconnectBT() async{
    try {
      //Definimos el comando a enviar al Arduino
      String disconnect = "Desconectar";
      //convertimos de texto a Uint8List el comando para poder enviarlo
      Uint8List outputAsUint8List = new Uint8List.fromList(disconnect.codeUnits);
      //Enviamos el comando "Desconectar" en formato Uint8List
      await this._bluetoothConnection.output.add(outputAsUint8List);
      //Usando la libreria de BT cerramos la conexion
      this._bluetoothConnection.close();
    } catch (exception) {
      print('Cannot connect, exception occured');
    }
    //seteamos el estado del widget en DESCONECTADO
    setState(() {
      this._connected = false;
    });
  }
}
