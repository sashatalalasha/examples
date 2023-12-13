part of 'recovery_bloc.dart';

@freezed
sealed class RecoveryState with _$RecoveryState {
  const factory RecoveryState(
      {RecoveryFlow? recoveryFlow,
      @Default(false) isLoading,
      String? settingsFlowId,
      String? message}) = _RecoveryState;
}