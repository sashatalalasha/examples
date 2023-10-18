// Copyright © 2023 Ory Corp
// SPDX-License-Identifier: Apache-2.0

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ory_client/ory_client.dart';

import '../../repositories/auth.dart';
import '../../services/exceptions.dart';
import '../auth/auth_bloc.dart';

part 'login_event.dart';
part 'login_state.dart';
part 'login_bloc.freezed.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthBloc authBloc;
  final AuthRepository repository;
  LoginBloc({required this.authBloc, required this.repository})
      : super(const LoginState()) {
    on<CreateLoginFlow>(_onCreateLoginFlow);
    on<GetLoginFlow>(_onGetLoginFlow);
    on<ChangeNodeValue>(_onChangeNodeValue);
    on<UpdateLoginFlow>(_onUpdateLoginFlow);
  }

  Future<void> _onCreateLoginFlow(
      CreateLoginFlow event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, message: null));
      final loginFlow = await repository.createLoginFlow(
          aal: event.aal, refresh: event.refresh);
      emit(state.copyWith(loginFlow: loginFlow, isLoading: false));
    } on UnknownException catch (e) {
      emit(state.copyWith(isLoading: false, message: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onGetLoginFlow(
      GetLoginFlow event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, message: null));
      final loginFlow = await repository.getLoginFlow(flowId: event.flowId);
      emit(state.copyWith(loginFlow: loginFlow, isLoading: false));
    } on UnknownException catch (e) {
      emit(state.copyWith(isLoading: false, message: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  _onChangeNodeValue(ChangeNodeValue event, Emitter<LoginState> emit) {
    if (state.loginFlow != null) {
      final newLoginState = repository.changeLoginNodeValue(
          settings: state.loginFlow!, name: event.name, value: event.value);
      emit(state.copyWith(loginFlow: newLoginState, message: null));
    }
  }

  _onUpdateLoginFlow(UpdateLoginFlow event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, message: null));
      final session = await repository.updateLoginFlow(
          flowId: state.loginFlow!.id,
          group: event.group,
          name: event.name,
          value: event.value,
          nodes: state.loginFlow!.ui.nodes.toList());
      authBloc.add(
          ChangeAuthStatus(status: AuthStatus.authenticated, session: session));
      emit(state.copyWith(isLoading: false));
    } on BadRequestException<LoginFlow> catch (e) {
      emit(state.copyWith(loginFlow: e.flow, isLoading: false));
    } on UnauthorizedException catch (_) {
      authBloc.add(ChangeAuthStatus(status: AuthStatus.unauthenticated));
    } on FlowExpiredException catch (e) {
      add(GetLoginFlow(flowId: e.flowId));
    } on TwoFactorAuthRequiredException catch (_) {
      authBloc.add(ChangeAuthStatus(status: AuthStatus.aal2Requested));
    } on UnknownException catch (e) {
      emit(state.copyWith(isLoading: false, message: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
