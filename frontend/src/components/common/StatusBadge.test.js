import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { describe, test, it, expect } from 'vitest';
import StatusBadge from './StatusBadge';

describe('StatusBadge Component', () => {
  test('renders nothing when no status is provided', () => {
    const { container } = render(<StatusBadge status="" />);
    expect(container.firstChild).toBeNull();
  });

  it.each([
    ['approved', 'Approved'],
    ['pending', 'Pending'],
    ['needs_changes', 'Needs Changes'],
  ])('renders %s status with label and classes', (status, label) => {
    render(<StatusBadge status={status} />);
    const badge = screen.getByText(label);
    expect(badge).toHaveClass('status-badge', `status-${status}`);
  });
});
