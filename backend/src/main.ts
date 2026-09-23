import 'reflect-metadata';
import './config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { resolve } from 'path';
import { AppModule } from './app';
import { Stream } from './stream';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.useStaticAssets(resolve(__dirname, '../public'), { prefix: '/iot' });
  app.get(Stream).attach(app.getHttpServer());
  const host = process.env.HOST ?? '0.0.0.0';
  await app.listen(Number(process.env.PORT ?? 3000), host);
}
void bootstrap();
