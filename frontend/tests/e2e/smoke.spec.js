const { test, expect } = require('@playwright/test');

test.describe('Smoke Test', () => {
  test('should load the landing page successfully', async ({ page }) => {
    // Navigate to the root URL (configured in playwright.config.js)
    await page.goto('/');

    // Assert the main landing page header is visible
    const heading = page.getByRole('heading', { name: 'Simplify. Track. Report. Grow.' });
    await expect(heading).toBeVisible();

    // Assert the sign-in action is visible on the landing page
    const signInLink = page.getByRole('link', { name: 'Sign In' });
    await expect(signInLink).toBeVisible();
  });
});
