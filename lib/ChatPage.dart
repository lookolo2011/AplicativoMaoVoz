import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:speech_recognition/speech_recognition.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;
  
  const ChatPage({this.server});
  
  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class VoiceHome extends StatefulWidget {
  final BluetoothDevice server;
  BluetoothConnection connection;

  VoiceHome(this.connection, {this.server});
  
  @override
  _VoiceHomeState createState() => new _VoiceHomeState(BluetoothConnection);
}

class _VoiceHomeState extends State<VoiceHome> {
  static final clientID = 0;
  static final maxMessageLength = 4096 - 3;

  List<_Message> messages = List<_Message>();
  String _messageBuffer = '';

  final TextEditingController textEditingController = new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;

  _VoiceHomeState(Type bluetoothConnection);
  bool get isConnected => widget.connection != null && widget.connection.isConnected;

  bool isDisconnecting = false;

//agora vai
  SpeechRecognition _speechRecognition;
  bool _isAvailable = false;
  bool _isListening = false;
  bool ligaVoz = false;

  String resultText = "A";

  @override
    initState() {
      
      super.initState();
      initSpeechRecognizer();

      //bluetooth();
    }


  void initSpeechRecognizer() {
    _speechRecognition = SpeechRecognition();

    _speechRecognition.setAvailabilityHandler(
      (bool result) => setState(() => _isAvailable = result),
    );

    _speechRecognition.setRecognitionStartedHandler(
      () => setState(() => _isListening = true),
    );

    _speechRecognition.setRecognitionResultHandler(
      (String speech) => setState(() => resultText = speech),
    );

    _speechRecognition.setRecognitionCompleteHandler(
      () => setState(() => _isListening = false),//
    );

    _speechRecognition.activate().then(
          (result) => setState(() => _isAvailable = result),
        );
  }

  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      widget.connection.dispose();
      widget.connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: new Scaffold(
                body: Column(
                  //Botões e saida de voz para baixo com o ".end"
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        FloatingActionButton(
                          child: Icon(Icons.cancel),
                          mini: true,
                          backgroundColor: Colors.deepOrange,
                          onPressed: () {
                            if (_isListening)
                              _speechRecognition.cancel().then(
                                    (result) => setState(() {
                                          _isListening = result;
                                          resultText = "";
                                        }),
                                  );
                          },
                        ),
                        FloatingActionButton(
                          child: Icon(Icons.mic),
                        onPressed: () async {
                          if (_isAvailable && !_isListening) {
                           // _speechRecognition.listen(locale: "pt_BR").then((result) => print('$result')).asStream();
                            _speechRecognition.listen(locale: "pt_BR").then((result) => {if(result == false) (_enviarComando(resultText))} );
                          }

                        },
                        ),
                        FloatingActionButton(
                          child: Icon(Icons.stop),
                          mini: true,
                          backgroundColor: Colors.deepPurple,
                          onPressed: () {
                            if (_isListening)
                              _speechRecognition.stop().then(
                                    (result) => setState(() => _isListening = result),
                                  );
                          },
                        ),
                      ],
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent[100],
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      child: Text(
                        resultText,
                        //Limite para pegar apenas 1 linha do que é falado
                        maxLines: 1,
                        style: TextStyle(fontSize: 24.0),
                      ),
                    )
                  ],
                ),
            ),
        );
  }

// enviaaaa voz

  String _converteVoz(String comandoVoz) {

    if(comandoVoz == "abrir mão") {
      return "A";
    }
    else if(comandoVoz == "fechar mão") {
      return "B";
    }
    else if(comandoVoz == "rock") {
      return "C";
    }
    else if(comandoVoz == "suave") {
      return "D";
    }
    else if(comandoVoz == "tranquilo") {
      return "E";
    }
    else if(comandoVoz == "homem-aranha") {
      return "F";
    }

    //se não for nenhum comando
    else return "";
  }

  void _enviarComando(String text) async {
    text = _converteVoz(text);
    text = text.trim();
    textEditingController.clear();
    
    print('lukinha:$text');
    if (text.length > 0)  {
      try {
        widget.connection.output.add(utf8.encode(text + "\r\n"));
        await widget.connection.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(listScrollController.position.maxScrollExtent, duration: Duration(milliseconds: 333), curve: Curves.easeOut);
        });
      }
      catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  static final maxMessageLength = 4096 - 3;
  BluetoothConnection connection;

  List<_Message> messages = List<_Message>();
  String _messageBuffer = '';

  final TextEditingController textEditingController = new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;

  bool isDisconnecting = false;


  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Conectado ao dispositivo');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        }
        else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      appBar: AppBar(
        title: (
          isConnecting ? Text('Conectando em ' + widget.server.name + '...') :
          isConnected ? Text('Conectado a ' + widget.server.name) :
          Text('Registro de ' + widget.server.name)
        ),
        bottom: new TabBar(
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: Colors.red,
          tabs: <Widget>[
            new Tab(text: "Voz"),
            new Tab(text: "Comandos"),
          ],
        ),
      ),
      body: new TabBarView(
      children: [
      //1 Tab = Comandos
      SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[

            //abre
            Text("Abre os Dedos"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text(
                      "Dedo 1",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("a") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 2",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("b") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 3",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("c") : null
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text(
                      "Dedo 4",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("d") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 5",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("e") : null
                ),
              ],
            ),

            //fecha
            Text("Fecha os Dedos"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text(
                      "Dedo 1",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("g") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 2",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("h") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 3",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("i") : null
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text(
                      "Dedo 4",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("j") : null
                ),
                RaisedButton(
                  child: Text(
                      "Dedo 5",
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("k") : null
                ),
              ],
            ),

            Text("Comandos prontos"),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                RaisedButton(
                  child: Text(
                      "Abre",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("A") : null
                ),
                RaisedButton(
                  child: Text(
                      "Fecha",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("B") : null
                ),
                RaisedButton(
                  child: Text(
                      "Rock",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("C") : null
                ),
                RaisedButton(
                  child: Text(
                      "Suave",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("D") : null
                ),
                RaisedButton(
                  child: Text(
                      "Tranquilo",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("E") : null
                ),
                RaisedButton(
                  child: Text(
                      "Vai Teia",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("F") : null
                ),
                RaisedButton(
                  child: Text(
                      "Suave",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("D") : null
                ),
                RaisedButton(
                  child: Text(
                      "Tranquilo",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("E") : null
                ),
                RaisedButton(
                  child: Text(
                      "Vai Teia",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("F") : null
                ),
                RaisedButton(
                  child: Text(
                      "Suave",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("D") : null
                ),
                RaisedButton(
                  child: Text(
                      "Tranquilo",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("E") : null
                ),
                RaisedButton(
                  child: Text(
                      "Vai Teia",
                      style: TextStyle(color: Colors.black, fontSize: 30),
                    ), //Text
                    onPressed: isConnected ? () => _sendMessage("F") : null
                ),
              ],
            )//
          ],
        )
      ),
      VoiceHome(connection),
      ]
      )
    )
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      }
      else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        }
        else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) { // \r\n
      setState(() {
        messages.add(_Message(1, 
          backspacesCounter > 0 
            ? _messageBuffer.substring(0, _messageBuffer.length - backspacesCounter) 
            : _messageBuffer
          + dataString.substring(0, index)
        ));
        _messageBuffer = dataString.substring(index);
      });
    }
    else {
      _messageBuffer = (
        backspacesCounter > 0 
          ? _messageBuffer.substring(0, _messageBuffer.length - backspacesCounter) 
          : _messageBuffer
        + dataString
      );
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0)  {
      try {
        connection.output.add(utf8.encode(text + "\r\n"));
        await connection.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(listScrollController.position.maxScrollExtent, duration: Duration(milliseconds: 333), curve: Curves.easeOut);
        });
      }
      catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}

