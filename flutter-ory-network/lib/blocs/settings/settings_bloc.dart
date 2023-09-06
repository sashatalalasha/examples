// Copyright © 2023 Ory Corp
// SPDX-License-Identifier: Apache-2.0

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:collection/collection.dart';
import 'package:ory_network_flutter/entities/message.dart';
import 'package:ory_network_flutter/repositories/auth.dart';

import '../../entities/formfield.dart';
import '../../repositories/settings.dart';
import '../../services/exceptions.dart';
import '../auth/auth_bloc.dart';

part 'settings_event.dart';
part 'settings_state.dart';

part 'settings_bloc.freezed.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final AuthBloc authBloc;
  final SettingsRepository repository;
  SettingsBloc({required this.authBloc, required this.repository})
      : super(SettingsState()) {
    on<CreateSettingsFlow>(_onCreateSettingsFlow);
    on<ChangePassword>(_onChangePassword);
    on<ChangePasswordVisibility>(_onChangePasswordVisibility);
    on<SubmitNewPassword>(_onSubmitNewPassword);
  }
  _onChangePassword(ChangePassword event, Emitter<SettingsState> emit) {
    // remove password and general error when changing email
    emit(state.copyWith
        .password(value: event.value, errorMessage: null)
        .copyWith(message: null));
  }

  _onChangePasswordVisibility(
      ChangePasswordVisibility event, Emitter<SettingsState> emit) {
    emit(state.copyWith(isPasswordHidden: event.value));
  }

  Future<void> _onCreateSettingsFlow(
      SettingsEvent event, Emitter<SettingsState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, message: null));

      final flowId = await repository.createSettingsFlow();

      emit(state.copyWith(isLoading: false, flowId: flowId));
    } on CustomException catch (e) {
      if (e case UnauthorizedException _) {
        // change auth status as the user is not authenticated
        authBloc.add(ChangeAuthStatus(status: AuthStatus.unauthenticated));
      } else if (e case UnknownException _) {
        emit(state.copyWith(
            isLoading: false,
            message: NodeMessage(text: e.message, type: MessageType.error)));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _onSubmitNewPassword(
      SubmitNewPassword event, Emitter<SettingsState> emit) async {
    try {
      emit(state
          .copyWith(isLoading: true, message: null)
          .copyWith
          .password(errorMessage: null));

      final messages = await repository.submitNewPassword(
          flowId: event.flowId, password: event.value);

      // password was successfully changed, reset password field and show general message.
      // for simplicity, only the first general message is shown in ui
      emit(state
          .copyWith(isLoading: false, message: messages?.first)
          .copyWith
          .password(value: ''));
    } on CustomException catch (e) {
      if (e case UnauthorizedException _) {
        // change auth status as the user is not authenticated
        authBloc.add(ChangeAuthStatus(status: AuthStatus.unauthenticated));
      } else if (e case BadRequestException _) {
        // get input and general errors.
        // for simplicity, only first messages of a specific context are shown in ui
        final passwordMessage = e.messages
            ?.firstWhereOrNull((element) => element.attr == 'password');
        final generalMessage = e.messages
            ?.firstWhereOrNull((element) => element.attr == 'general');

        // update state to new one with errors
        emit(state
            .copyWith(isLoading: false, message: generalMessage)
            .copyWith
            .password(errorMessage: passwordMessage?.text));
      } else if (e case FlowExpiredException _) {
        // use new flow id, reset fields and show error
        emit(state
            .copyWith(
                flowId: e.flowId,
                message: NodeMessage(text: e.message, type: MessageType.error),
                isLoading: false)
            .copyWith
            .password(value: ''));
      } else if (e case UnknownException _) {
        emit(state.copyWith(
            isLoading: false,
            message: NodeMessage(text: e.message, type: MessageType.error)));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    }
  }
}
