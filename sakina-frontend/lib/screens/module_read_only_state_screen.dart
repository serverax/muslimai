import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/module_service.dart';

class ModuleReadOnlyStateScreen<T extends ModuleOverviewDto>
    extends StatelessWidget {
  const ModuleReadOnlyStateScreen({
    super.key,
    required this.title,
    required this.load,
  });

  final String title;
  final Future<ModuleResult<T>> Function() load;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModuleResult<T>>(
      future: load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FormatException) {
            return _stateText(
                '$title is temporarily unavailable due to malformed backend data.');
          }
          if (error is ApiException) {
            if (error.statusCode == 401 || error.statusCode == 403) {
              return _stateText('Unauthorized. Please sign in again.');
            }
            if (error.statusCode == 402 ||
                error.errorCode == 'subscription_required') {
              return _stateText('$title requires premium subscription.');
            }
            if (error.errorCode == 'feature_disabled') {
              return _stateText('$title is disabled by backend policy.');
            }
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$title is unavailable right now.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final result = snapshot.data!;
        switch (result.state) {
          case ModuleAccessState.featureDisabled:
            return _stateText('$title is disabled by feature flag.');
          case ModuleAccessState.subscriptionRequired:
            return _stateText('$title requires premium subscription.');
          case ModuleAccessState.enabledReadOnly:
          case ModuleAccessState.requiresReview:
            final overview = result.overview;
            final scholarReviewWarning = overview != null &&
                overview.reviewStatus == ReviewStatus.scholarReviewRequired;
            if (overview == null || overview.provenance.isEmpty) {
              return _stateText(
                scholarReviewWarning
                    ? '$title under review. Please consult a qualified scholar.'
                    : '$title is unavailable in this release.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (scholarReviewWarning)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Scholar review required before guidance is shown.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                Text(
                  result.message,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final p in overview.provenance)
                  ListTile(
                    title: Text(p.sourceName),
                    subtitle: Text(
                      '${p.sourceType} | ${p.sourceReference}\n'
                      'review: ${p.reviewStatus}'
                      '${p.effectiveDate != null ? ' | effective: ${p.effectiveDate}' : ''}',
                    ),
                  ),
              ],
            );
        }
      },
    );
  }

  Widget _stateText(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
