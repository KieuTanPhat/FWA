import { Inject, Injectable, Logger } from '@nestjs/common';
import { applicationDefault, getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { Database } from './database';
import { demoRegions } from './demo-regions';

@Injectable()
export class PushNotifications {
  private readonly logger = new Logger(PushNotifications.name);
  private readonly messaging?: Messaging;

  constructor(@Inject(Database) private readonly db: Database) {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      this.logger.warn('FCM đang tắt: chưa cấu hình GOOGLE_APPLICATION_CREDENTIALS.');
      return;
    }

    try {
      const app = getApps().length > 0
        ? getApp()
        : initializeApp({
            credential: applicationDefault(),
            ...(process.env.FIREBASE_PROJECT_ID
              ? { projectId: process.env.FIREBASE_PROJECT_ID }
              : {}),
          });
      this.messaging = getMessaging(app);
      this.logger.log('Đã bật gửi cảnh báo nền qua Firebase Cloud Messaging.');
    } catch (error) {
      this.logger.error(`Không khởi tạo được FCM: ${this.errorText(error)}`);
    }
  }

  get enabled() {
    return this.messaging !== undefined;
  }

  async notifyAlert(stationId: string, alertId: string, riskLevel: string) {
    if (!this.messaging || !['WARNING', 'EMERGENCY'].includes(riskLevel)) return;

    try {
      const tokens = await this.db.notificationTokens(stationId);
      if (tokens.length === 0) return;

      const region = demoRegions.find(item => item.stationId === stationId);
      const sensorName = region?.sensorName ?? `Cảm biến ${stationId}`;
      const area = region?.name ?? '';
      const occurredAt = new Date().toISOString();
      const result = await this.messaging.sendEach(tokens.map(token => ({
        token,
        data: {
          alert_id: alertId,
          station_id: stationId,
          station_name: sensorName,
          area,
          occurred_at: occurredAt,
          risk_level: riskLevel,
        },
        android: {
          priority: 'high' as const,
          ttl: 60 * 60 * 1000,
        },
      })));

      const staleTokens = result.responses.flatMap((response, index) => {
        const code = response.error?.code;
        return code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ? [tokens[index]]
          : [];
      });
      await Promise.all(staleTokens.map(token => this.db.removeNotificationDevice(token)));

      if (result.failureCount > 0) {
        this.logger.warn(`FCM gửi ${result.successCount}/${tokens.length} cảnh báo tới ${stationId}.`);
      }
    } catch (error) {
      this.logger.error(`Gửi FCM thất bại cho ${stationId}: ${this.errorText(error)}`);
    }
  }

  private errorText(error: unknown) {
    return error instanceof Error ? error.message : String(error);
  }
}
