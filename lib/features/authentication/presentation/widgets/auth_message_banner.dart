import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          curr is AuthFailureState || prev is AuthFailureState,
      builder: (context, state) {
        if (state is! AuthFailureState) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: context.rh(16)),
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(14),
            vertical: context.rh(12),
          ),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(context.rr(10)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: context.rr(20),
                color: scheme.onErrorContainer,
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Text(
                  state.message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: context.rsp(13.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
