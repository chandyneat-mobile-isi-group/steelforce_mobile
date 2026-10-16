enum VisitStatus {
  pending,
  enRoute,
  arrived,
  checkedIn,
  checkedOut,
  missed;

  String get label => switch (this) {
        VisitStatus.pending => 'Pending',
        VisitStatus.enRoute => 'En Route',
        VisitStatus.arrived => 'Arrived',
        VisitStatus.checkedIn => 'Checked In',
        VisitStatus.checkedOut => 'Completed',
        VisitStatus.missed => 'Missed',
      };

  bool get isComplete => this == VisitStatus.checkedOut;
}
