import 'reflect-metadata';
import './config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app';
import { Stream } from './stream';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.get(Stream).attach(app.getHttpServer());
  const host = process.env.HOST ?? '0.0.0.0';
  await app.listen(Number(process.env.PORT ?? 3000), host);
}
void bootstrap();
