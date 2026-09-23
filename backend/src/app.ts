import { BadRequestException, Controller, Get, Injectable, Module, NotFoundException, Param, Query } from '@nestjs/common';
import { Database } from './database';
import { MqttIngest } from './mqtt-ingest';
import { Stream } from './stream';

function limitOf(raw: string | undefined) {
  const n = raw === undefined ? 50 : Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 200) throw new BadRequestException('limit phải từ 1 đến 200');
  return n;
}
function dateOf(raw: string | undefined) {
  if (raw === undefined) return undefined;
  const d = new Date(raw);
  if (!/^\d{4}-\d{2}-\d{2}T/.test(raw) || Number.isNaN(d.getTime())) throw new BadRequestException('Thời gian phải là ISO-8601');
  return d;
}

@Controller()
class ApiController {
  constructor(private readonly db: Database) {}

  @Get('/healthz')
  async health() {
    await this.db.pool.query('SELECT 1');
    return { status: 'ok' };
  }

  @Get('/api/v1/stations')
  async stations() { return this.db.stations(Number(process.env.STALE_AFTER_SECONDS ?? 15)); }

  @Get('/api/v1/stations/:id/latest')
  async latest(@Param('id') id: string) {
    const station = (await this.db.stations(Number(process.env.STALE_AFTER_SECONDS ?? 15))).find(s => s.id === id);
    if (!station) throw new NotFoundException('Không tìm thấy trạm');
    return station;
  }

  @Get('/api/v1/stations/:id/telemetry')
  async telemetry(@Param('id') id: string, @Query('limit') limit?: string, @Query('from') from?: string, @Query('to') to?: string) {
    if (!await this.db.station(id)) throw new NotFoundException('Không tìm thấy trạm');
    const start = dateOf(from), end = dateOf(to);
    if (start && end && (start > end || end.getTime() - start.getTime() > 7 * 86400000)) {
      throw new BadRequestException('Khoảng thời gian tối đa 7 ngày');
    }
    return this.db.telemetry(id, limitOf(limit), start, end);
  }

  @Get('/api/v1/alerts')
  async alerts(@Query('station_id') id?: string, @Query('limit') limit?: string, @Query('before') before?: string) {
    if (id && !await this.db.station(id)) throw new NotFoundException('Không tìm thấy trạm');
    return this.db.alerts(id, limitOf(limit), dateOf(before));
  }
}

@Module({ controllers: [ApiController], providers: [Database, Stream, MqttIngest], exports: [Stream] })
export class AppModule {}

