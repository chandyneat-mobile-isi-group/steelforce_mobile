import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';

sealed class DepotDetailState extends Equatable {
  const DepotDetailState();
  @override
  List<Object?> get props => [];
}

final class DepotDetailLoading extends DepotDetailState {
  const DepotDetailLoading();
}

final class DepotDetailLoaded extends DepotDetailState {
  const DepotDetailLoaded({
    required this.depot,
    required this.notes,
    required this.activities,
    this.isAddingNote = false,
  });

  final Depot depot;
  final List<DepotNote> notes;
  final List<DepotActivity> activities;
  final bool isAddingNote;

  DepotDetailLoaded copyWith({
    Depot? depot,
    List<DepotNote>? notes,
    List<DepotActivity>? activities,
    bool? isAddingNote,
  }) {
    return DepotDetailLoaded(
      depot: depot ?? this.depot,
      notes: notes ?? this.notes,
      activities: activities ?? this.activities,
      isAddingNote: isAddingNote ?? this.isAddingNote,
    );
  }

  @override
  List<Object?> get props => [depot, notes, activities, isAddingNote];
}

final class DepotDetailError extends DepotDetailState {
  const DepotDetailError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
