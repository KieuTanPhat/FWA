import { Injectable } from '@nestjs/common';
import { Server as HttpServer } from 'http';
import { WebSocket, WebSocketServer } from 'ws';

@Injectable()
export class Stream {
  private server?: WebSocketServer;

  attach(http: HttpServer) {
    this.server = new WebSocketServer({ server: http, path: '/api/v1/stream' });
  }

  publish(event: string, data: unknown) {
    const message = JSON.stringify({ event, data });
    for (const socket of this.server?.clients ?? []) {
      if (socket.readyState === WebSocket.OPEN) socket.send(message);
    }
  }
}

