String rm(num value) => 'RM ${value.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'am' : 'pm'}';
}

/// e.g. "31 Oct, 4:05 pm", or "Today, 4:05 pm".
String shortDateTime(DateTime time) {
  final now = DateTime.now();
  final isToday = time.year == now.year && time.month == now.month && time.day == now.day;
  return '${isToday ? 'Today' : '${time.day} ${_months[time.month - 1]}'}, ${clockTime(time)}';
}

String timeAgo(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  return '${elapsed.inDays} d ago';
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Selamat pagi';
  if (hour < 19) return 'Selamat petang';
  return 'Selamat malam';
}
