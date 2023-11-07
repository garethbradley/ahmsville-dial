import '../models/dial_model.dart';

enum SerialIsolateMessageCommand {
  initiate,
  connect,
  disconnect,
  getStatus,
  sendData,
}

enum SerialIsolateResponseType {
  status,
  data,
  button
}

class SerialIsolateMessage {
  SerialIsolateMessage(this.command, this.message);

  final SerialIsolateMessageCommand command;
  final String message;

}

class SerialIsolateResponse {
  SerialIsolateResponse(this.type, this.message);
  SerialIsolateResponse.withAddress(this.type, this.message, this.address);
  SerialIsolateResponse.dataUpdate({this.type = SerialIsolateResponseType.data, this.message = '', required this.data});

  final SerialIsolateResponseType type;
  final String message;
  String? address;
  DialModel? data;
}