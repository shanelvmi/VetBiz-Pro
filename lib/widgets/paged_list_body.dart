import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/cursor_paginated_list_controller.dart';
import '../theme/app_dimens.dart';
import 'firestore_error_view.dart';
import 'list_page_bar.dart';
import 'phone_list/phone_list_skeleton.dart';

/// PAGE1: a server-paged list on PC and tablet, one widget for Transactions,
/// Payments, Activity Log, Notifications and Trash: the page from
/// [controller] and the shared ListPageBar under it.
///
/// While the first page of a session loads: the skeleton rows (no spinner).
/// While Next loads: the page already shown stays, dimmed, so the list never
/// flashes empty. A failed fetch: the error text with Retry (the same fetch
/// again). Nothing on the page: [empty].
class PagedListBody<T> extends StatelessWidget {
  const PagedListBody({
    super.key,
    required this.controller,
    required this.empty,
    required this.barEmptyText,
    required this.list,
  });

  final CursorPaginatedListController<T> controller;
  final Widget empty;
  final String barEmptyText;

  /// The rows of the page shown.
  final Widget Function(List<T> items) list;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        final Widget body;
        if (controller.error != null && !controller.isLoading) {
          body = Center(
            key: const ValueKey('pagedList-error'),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FirestoreErrorView(error: controller.error),
                  OutlinedButton(onPressed: controller.retry, child: Text(context.l10n.common_retry)),
                ],
              ),
            ),
          );
        } else if (controller.isLoading && items.isEmpty) {
          body = const SingleChildScrollView(
            key: ValueKey('pagedList-skeleton'),
            child: PhoneListSkeleton(),
          );
        } else if (items.isEmpty) {
          body = empty;
        } else {
          body = IgnorePointer(
            ignoring: controller.isLoading,
            child: Opacity(
              key: const ValueKey('pagedList-page'),
              opacity: controller.isLoading ? AppAlpha.a50 : 1,
              child: list(items),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            ListPageBar(
              emptyText: barEmptyText,
              itemCount: items.length,
              pageSize: controller.pageSize,
              currentPage: controller.currentPage < 1 ? 1 : controller.currentPage,
              hasPreviousPage: controller.hasPreviousPage && !controller.isLoading,
              hasNextPage: controller.hasNextPage,
              isLoading: controller.isLoading,
              showLoadingSpinner: false,
              onPageSize: controller.setPageSize,
              onPrevious: controller.goToPreviousPage,
              onNext: controller.goToNextPage,
            ),
          ],
        );
      },
    );
  }
}
