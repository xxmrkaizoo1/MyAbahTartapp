"""Sales forecast, revenue forecast and trend analysis.

Python version of lib/services/sales_forecast.dart. The maths is the same, so the
script and the app give the same numbers for the same orders.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from enum import Enum

WEEKDAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']


@dataclass
class OrderItem:
    name: str
    quantity: int


@dataclass
class ShopOrder:
    """Only the parts of an order the forecasts use. No customer details."""

    created_at: datetime
    total: float
    status: str = 'completed'
    channel: str = 'online'
    refunded_amount: float = 0
    items: list[OrderItem] = field(default_factory=list)

    @property
    def net_total(self) -> float:
        """Total minus what has already been refunded."""
        return round_half_up((self.total - self.refunded_amount) * 100) / 100

    @property
    def item_count(self) -> int:
        return sum(item.quantity for item in self.items)

    @property
    def is_cancelled(self) -> bool:
        return self.status == 'cancelled'


def round_half_up(value: float) -> int:
    """Rounds like Dart's round(): halves go away from zero, not to the even number."""
    return int(Decimal(value).quantize(Decimal(1), rounding=ROUND_HALF_UP))


def fixed(value: float, digits: int) -> str:
    """Formats like Dart's toStringAsFixed()."""
    return str(Decimal(value).quantize(Decimal(1).scaleb(-digits), rounding=ROUND_HALF_UP))


def _day_of(time: datetime) -> date:
    return time.date()


def _midnight(day: date) -> datetime:
    return datetime(day.year, day.month, day.day)


@dataclass
class SalesHistory:
    """Sales per day, from the first sale up to yesterday. Today is left out because
    a half-finished day would look like a drop in sales."""

    first_day: date
    revenue: list[float]
    items: list[float]

    @classmethod
    def from_orders(cls, orders: list[ShopOrder], now: datetime) -> SalesHistory:
        today = _day_of(now)
        counted = [order for order in orders if not order.is_cancelled and _day_of(order.created_at) < today]
        if not counted:
            return cls(first_day=today, revenue=[], items=[])

        first_day = min(_day_of(order.created_at) for order in counted)
        length = (today - first_day).days
        revenue = [0.0] * length
        items = [0.0] * length
        for order in counted:
            index = (_day_of(order.created_at) - first_day).days
            revenue[index] += order.net_total
            items[index] += order.item_count
        return cls(first_day=first_day, revenue=revenue, items=items)


class ForecastConfidence(Enum):
    LOW = 'Low'
    MEDIUM = 'Medium'
    HIGH = 'High'

    @property
    def label(self) -> str:
        return self.value


def _line(series: list[float]) -> tuple[float, float]:
    """Straight line through the figures: returns (intercept, slope)."""
    n = len(series)
    mean_t = (n - 1) / 2
    mean_y = sum(series) / n
    top = sum((t - mean_t) * (series[t] - mean_y) for t in range(n))
    bottom = sum((t - mean_t) ** 2 for t in range(n))
    slope = 0.0 if bottom == 0 else top / bottom
    return mean_y - slope * mean_t, slope


class _Fit:
    """A trend line with a weekly pattern, fitted to daily figures."""

    # How quickly a trend fades. Without this a good fortnight would be projected
    # as growing forever.
    TREND_FADE = 0.9

    def __init__(self, values: list[float], first_day: date):
        n = len(values)
        first_weekday = first_day.weekday()  # Monday is 0

        # Weekdays are measured against the trend, not the overall average, or
        # growth would make the later days of the week look busier than they are.
        rough_intercept, rough_slope = _line(values)
        totals = [0.0] * 7
        counts = [0] * 7
        for t in range(n):
            expected = rough_intercept + rough_slope * t
            if expected <= 0:
                continue
            slot = (first_weekday + t) % 7
            totals[slot] += values[t] / expected
            counts[slot] += 1

        # A weekday seen only a few times is pulled towards "average" so that one
        # busy Saturday isn't taken for a pattern.
        raw = [(totals[slot] + 1) / (counts[slot] + 1) for slot in range(7)]
        raw_mean = sum(raw) / 7
        factors = [factor / raw_mean for factor in raw]

        def factor_at(t: int) -> float:
            return factors[(first_weekday + t) % 7]

        intercept, slope = _line([values[t] / factor_at(t) for t in range(n)])

        squared = 0.0
        for t in range(n):
            residual = values[t] - factor_at(t) * (intercept + slope * t)
            squared += residual * residual

        self._level = intercept + slope * (n - 1)
        self._slope = slope
        self._weekday_factors = factors
        self._first_weekday = first_weekday
        self._length = n
        self.error_per_day = math.sqrt(squared / (n - 2)) if n > 2 else 0.0

    def predict(self, days: int) -> list[float]:
        result = []
        drift = 0.0
        fade = 1.0
        for ahead in range(1, days + 1):
            fade *= self.TREND_FADE
            drift += self._slope * fade
            factor = self._weekday_factors[(self._first_weekday + self._length - 1 + ahead) % 7]
            result.append(max(0.0, (self._level + drift) * factor))
        return result


@dataclass
class Forecast:
    """What the next len(daily) days are likely to bring."""

    first_day: date
    daily: list[float]
    total: float
    low: float
    high: float
    confidence: ForecastConfidence
    # How far off a test on the latest week was (0.2 = 20%); None if it couldn't be tested.
    past_error: float | None = None

    # Less history than this gives a guess, not a forecast.
    MIN_DAYS = 14
    MIN_DAYS_WITH_SALES = 5
    _TEST_DAYS = 7

    @classmethod
    def compute(cls, values: list[float], history_start: date, days: int) -> Forecast | None:
        """Returns None when there isn't enough history to say anything useful."""
        days_with_sales = sum(1 for value in values if value > 0)
        if len(values) < cls.MIN_DAYS or days_with_sales < cls.MIN_DAYS_WITH_SALES:
            return None

        fit = _Fit(values, history_start)
        daily = fit.predict(days)
        total = sum(daily)
        # On simulated sales, about 7 forecasts in 10 landed inside this range.
        spread = 1.28 * fit.error_per_day * math.sqrt(days)

        past_error = cls._test_on_recent_days(values, history_start)
        return cls(
            first_day=history_start + timedelta(days=len(values)),
            daily=daily,
            total=total,
            low=max(0.0, total - spread),
            high=total + spread,
            past_error=past_error,
            confidence=cls._confidence_for(len(values), days_with_sales, past_error),
        )

    @classmethod
    def _test_on_recent_days(cls, values: list[float], history_start: date) -> float | None:
        """Hides the latest week, predicts it, and compares with what really happened."""
        training_length = len(values) - cls._TEST_DAYS
        if training_length < cls.MIN_DAYS:
            return None
        actual = sum(values[training_length:])
        if actual <= 0:
            return None
        predicted = sum(_Fit(values[:training_length], history_start).predict(cls._TEST_DAYS))
        return abs(predicted - actual) / actual

    @staticmethod
    def _confidence_for(length: int, days_with_sales: int, past_error: float | None) -> ForecastConfidence:
        if past_error is None:
            return ForecastConfidence.LOW
        if length >= 56 and days_with_sales >= length / 2 and past_error <= 0.2:
            return ForecastConfidence.HIGH
        if length >= 28 and past_error <= 0.4:
            return ForecastConfidence.MEDIUM
        return ForecastConfidence.LOW


@dataclass
class ProductTrend:
    name: str
    recent_units: int
    previous_units: int

    @property
    def difference(self) -> int:
        return self.recent_units - self.previous_units

    @property
    def change(self) -> float | None:
        """None for a product with no sales in the earlier period."""
        return None if self.previous_units == 0 else self.difference / self.previous_units * 100


@dataclass
class TrendReport:
    """How the latest period compares with the one before it."""

    days: int
    revenue: float
    orders: int
    items: int
    # False until there is a full earlier period to compare with.
    has_comparison: bool
    revenue_change: float | None = None
    orders_change: float | None = None
    items_change: float | None = None
    rising: list[ProductTrend] = field(default_factory=list)
    falling: list[ProductTrend] = field(default_factory=list)
    best_weekday: str | None = None
    slowest_weekday: str | None = None
    # Percentage of revenue that came from online orders.
    online_share: float | None = None

    # A product needs this many units across both periods to count as a trend,
    # otherwise selling 2 instead of 1 reads as "+100%".
    MIN_UNITS_FOR_TREND = 5

    @classmethod
    def from_orders(cls, orders: list[ShopOrder], now: datetime, days: int = 30) -> TrendReport:
        today_day = _day_of(now)
        today = _midnight(today_day)
        recent_start = _midnight(today_day - timedelta(days=days))
        previous_start = _midnight(today_day - timedelta(days=days * 2))
        counted = [order for order in orders if not order.is_cancelled]

        recent = [order for order in counted if recent_start <= order.created_at < today]
        previous = [order for order in counted if previous_start <= order.created_at < recent_start]

        # A shop that started selling halfway through the earlier period would show
        # growth that isn't real, so that period must be complete to compare with it.
        has_comparison = bool(previous) and any(_day_of(order.created_at) <= previous_start.date() for order in counted)

        def net(group: list[ShopOrder]) -> float:
            return sum(order.net_total for order in group)

        def items_in(group: list[ShopOrder]) -> int:
            return sum(order.item_count for order in group)

        def change(current: float, earlier: float) -> float | None:
            return None if not has_comparison or earlier <= 0 else (current - earlier) / earlier * 100

        recent_revenue = net(recent)

        weekday_revenue = [0.0] * 7
        weekday_count = [0] * 7
        for offset in range(1, days + 1):
            weekday_count[(today_day - timedelta(days=offset)).weekday()] += 1
        for order in recent:
            weekday_revenue[order.created_at.weekday()] += order.net_total
        averages = [0.0 if weekday_count[slot] == 0 else weekday_revenue[slot] / weekday_count[slot] for slot in range(7)]
        best = 0
        slowest = 0
        for slot in range(1, 7):
            if averages[slot] > averages[best]:
                best = slot
            if averages[slot] < averages[slowest]:
                slowest = slot

        rising: list[ProductTrend] = []
        falling: list[ProductTrend] = []
        if has_comparison:

            def units_by(group: list[ShopOrder]) -> dict[str, int]:
                units: dict[str, int] = {}
                for order in group:
                    for item in order.items:
                        units[item.name] = units.get(item.name, 0) + item.quantity
                return units

            recent_units = units_by(recent)
            previous_units = units_by(previous)
            for name in dict.fromkeys([*recent_units, *previous_units]):
                trend = ProductTrend(name, recent_units.get(name, 0), previous_units.get(name, 0))
                if trend.recent_units + trend.previous_units < cls.MIN_UNITS_FOR_TREND:
                    continue
                if trend.difference > 0:
                    rising.append(trend)
                if trend.difference < 0:
                    falling.append(trend)
            rising.sort(key=lambda trend: -trend.difference)
            falling.sort(key=lambda trend: trend.difference)

        online = [order for order in recent if order.channel == 'online']

        return cls(
            days=days,
            revenue=recent_revenue,
            orders=len(recent),
            items=items_in(recent),
            has_comparison=has_comparison,
            revenue_change=change(recent_revenue, net(previous)),
            orders_change=change(len(recent), len(previous)),
            items_change=change(items_in(recent), items_in(previous)),
            rising=rising[:3],
            falling=falling[:3],
            best_weekday=None if not recent else WEEKDAY_NAMES[best],
            slowest_weekday=None if not recent or best == slowest else WEEKDAY_NAMES[slowest],
            online_share=None if recent_revenue <= 0 else net(online) / recent_revenue * 100,
        )


def signed(value: float) -> str:
    return f"{'+' if value >= 0 else ''}{fixed(value, 1)}%"


def _trend_line(trend: ProductTrend) -> str:
    change = trend.change
    return f'{trend.name}: {trend.recent_units} units, was {trend.previous_units}' + ('' if change is None else f' ({signed(change)})')


def build_insight_prompt(*, days: int, revenue: Forecast | None, sales: Forecast | None, trend: TrendReport) -> str:
    """The prompt for the local model. It only ever sees shop totals and product
    names, never customer details, and is told not to do its own maths because
    small models get sums wrong."""

    def money(value: float) -> str:
        return f'RM {fixed(value, 0)}'

    lines = [
        'You are a sales analyst for a small tart bakery in Malaysia.',
        'Use ONLY the facts below. Do not calculate, estimate or invent any other numbers.',
        '',
        'FACTS',
        f'Last {trend.days} days: revenue {money(trend.revenue)}, {trend.orders} orders, {trend.items} items sold.',
    ]
    if trend.revenue_change is not None:
        lines.append(f'Revenue change from the previous {trend.days} days: {signed(trend.revenue_change)}.')
    if trend.orders_change is not None:
        lines.append(f'Orders change from the previous {trend.days} days: {signed(trend.orders_change)}.')
    if revenue is not None:
        lines.append(
            f'Revenue forecast for the next {days} days: {money(revenue.total)} '
            f'(likely {money(revenue.low)} to {money(revenue.high)}, {revenue.confidence.label.lower()} confidence).'
        )
    if sales is not None:
        lines.append(
            f'Items forecast for the next {days} days: about {round_half_up(sales.total)} '
            f'(likely {round_half_up(sales.low)} to {round_half_up(sales.high)}).'
        )
    if trend.best_weekday is not None:
        lines.append(f'Best weekday: {trend.best_weekday}.')
    if trend.slowest_weekday is not None:
        lines.append(f'Slowest weekday: {trend.slowest_weekday}.')
    if trend.online_share is not None:
        lines.append(f'Online orders: {fixed(trend.online_share, 0)}% of revenue. The rest is counter sales.')
    lines += [f'Selling more: {_trend_line(product)}.' for product in trend.rising]
    lines += [f'Selling less: {_trend_line(product)}.' for product in trend.falling]
    lines += [
        '',
        'Write exactly 3 short bullet points for the shop owner:',
        '1. What is happening.',
        '2. What to prepare for.',
        '3. One practical action.',
    ]
    return '\n'.join(lines)
