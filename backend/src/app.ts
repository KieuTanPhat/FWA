import { BadRequestException, Body, Controller, Get, Inject, Module, NotFoundException, Param, Patch, Post, Provider, Query } from '@nestjs/common';
import { Database } from './database';
import { demoControlPatchSchema, notificationDeviceSchema } from './contracts';
import { DemoSimulator } from './demo-simulator';
import { MqttIngest } from './mqtt-ingest';
import { PushNotifications } from './push-notifications';
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
  constructor(
    @Inject(Database) private readonly db: Database,
    @Inject(DemoSimulator) private readonly simulator: DemoSimulator,
    @Inject(PushNotifications) private readonly push: PushNotifications,
  ) {}

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
  async telemetry(
    @Param('id') id: string,
    @Query('limit') limit?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('window') window?: string,
  ) {
    if (!await this.db.station(id)) throw new NotFoundException('Không tìm thấy trạm');
    if (window !== undefined) {
      if (window !== '1h') throw new BadRequestException('window chỉ hỗ trợ 1h');
      return this.db.telemetryLastHour(id);
    }
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

  @Post('/api/v1/notifications/register')
  async registerNotificationDevice(@Body() body: unknown) {
    const parsed = notificationDeviceSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('station_id hoặc mã thiết bị thông báo không hợp lệ.');
    }
    if (!await this.db.station(parsed.data.station_id)) {
      throw new NotFoundException('Không tìm thấy trạm');
    }
    await this.db.registerNotificationDevice(parsed.data.station_id, parsed.data.fcm_token);
    return { registered: true, push_enabled: this.push.enabled };
  }

  @Get('/api/v1/demo/stations/:id/control')
  async demoControl(@Param('id') id: string) {
    return this.simulator.getControl(id);
  }

  @Patch('/api/v1/demo/stations/:id/control')
  async updateDemoControl(@Param('id') id: string, @Body() body: unknown) {
    const parsed = demoControlPatchSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.issues.map(issue => issue.message).join('; '));
    }
    try {
      return await this.simulator.updateControl(id, parsed.data);
    } catch (error) {
      if (error instanceof Error &&
          (error.message.startsWith('Ngưỡng') || error.message.startsWith('Mực nước'))) {
        throw new BadRequestException(error.message);
      }
      throw error;
    }
  }
}

const providers: Provider[] = [Database, Stream, PushNotifications];
providers.push(DemoSimulator);
if (process.env.MQTT_ENABLED !== 'false') providers.push(MqttIngest);

@Module({ controllers: [ApiController], providers, exports: [Stream] })
export class AppModule {}
