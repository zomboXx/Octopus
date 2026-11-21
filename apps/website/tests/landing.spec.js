import {test, expect} from '@playwright/test';

test('landing shows the shared catalog, labeled illustrative feedback, and links to the demo and APK', async ({page}) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  for (const width of [390, 1440]) {
    await page.setViewportSize({width, height: 850});
    await page.goto('/');
    const plans = page.locator('#plans');
    await expect(plans.getByRole('heading', {name: 'Starter'})).toBeVisible();
    await expect(plans.getByRole('heading', {name: 'Focus Pro'})).toBeVisible();
    await expect(plans.getByRole('heading', {name: 'Organization'})).toBeVisible();
    await expect(plans.getByText('Gói dự kiến · Chưa mở đăng ký')).toHaveCount(2);
    await expect(page.locator('#feedback-preview-label')).toHaveText('Phản hồi minh họa');
    await expect(page.locator('#feedback-preview-label')).toBeVisible();
    await expect(page.locator('#android-download')).toHaveAttribute('href', /octopus(?:-\d+\.\d+\.\d+)?-android-debug\.apk$/);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  }
  await page.getByRole('link', {name: 'Thử Starter', exact: true}).click();
  await expect(page).toHaveURL(/\/try\/$/);
  await expect(page.getByRole('button', {name: 'Dùng hồ sơ mẫu An'})).toBeVisible();
  expect(errors).toEqual([]);
});

test('analytics records activity only after consent and reuses the session between landing and demo', async ({page}) => {
  const events = [];
  await page.route('**/api/web-events', async route => {
    events.push(JSON.parse(route.request().postData()));
    await route.fulfill({status: 204});
  });
  await page.goto('/');
  const choice = page.locator('[data-analytics-page]');
  await choice.locator('summary').click();
  await choice.getByRole('button', {name: 'Từ chối'}).click();
  await expect(choice.getByRole('status')).toHaveText('Đã tắt thống kê.');
  await page.locator('.hero-actions a[href="#download"]').click();
  expect(events).toHaveLength(0);
  await choice.getByRole('button', {name: 'Cho phép thống kê'}).click();
  await expect.poll(() => events.filter(event => event.kind === 'visit').length).toBe(1);
  await page.locator('.hero-actions a[href="#download"]').click();
  await expect.poll(() => events.some(event => event.kind === 'android_interest')).toBeTruthy();
  await page.getByRole('link', {name: 'Thử Starter', exact: true}).click();
  await expect.poll(() => events.filter(event => event.kind === 'demo_start').length).toBe(1);
  expect(new Set(events.map(event => event.sessionId)).size).toBe(1);
  await page.reload();
  await expect.poll(() => events.filter(event => event.kind === 'visit').length).toBe(3);
  expect(events.filter(event => event.kind === 'demo_start')).toHaveLength(1);
  await choice.locator('summary').click();
  await choice.getByRole('button', {name: 'Tắt thống kê'}).click();
  await expect(choice.getByRole('status')).toHaveText('Đã tắt thống kê.');
  const before = events.length;
  await page.reload();
  expect(events).toHaveLength(before);
});
