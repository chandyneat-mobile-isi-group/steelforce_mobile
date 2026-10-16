/// Web: the browser does not expose an OS version we can trust, and the
/// server already records the User-Agent. Sending null leaves the session row
/// honest instead of filling it with a sniffed guess.
String? readOsVersion() => null;

String? readHostName() => null;
