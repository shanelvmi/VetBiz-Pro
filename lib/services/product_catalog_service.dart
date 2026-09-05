import '../models/product.dart';
import '../constants/product_categories.dart';

/// How the catalog should be sorted. Kept as a closed set of named
/// options (rather than a raw field name + direction) so the UI layer
/// never needs to know which Product field backs a given choice - that
/// mapping lives entirely in ProductCatalogService.
enum ProductSortOption {
  nameAsc,
  nameDesc,
  priceLowHigh,
  priceHighLow,
  stockLowHigh,
  stockHighLow,
  expirySoonestFirst,
}

extension ProductSortOptionLabel on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.nameAsc:
        return 'Name (A-Z)';
      case ProductSortOption.nameDesc:
        return 'Name (Z-A)';
      case ProductSortOption.priceLowHigh:
        return 'Price (Low-High)';
      case ProductSortOption.priceHighLow:
        return 'Price (High-Low)';
      case ProductSortOption.stockLowHigh:
        return 'Stock (Low-High)';
      case ProductSortOption.stockHighLow:
        return 'Stock (High-Low)';
      case ProductSortOption.expirySoonestFirst:
        return 'Expiry (Soonest First)';
    }
  }
}

/// A page size the person can pick from the catalog's own page-size
/// control - null specifically means "show everything, no pagination
/// at all", not merely a very large number, so a small facility's
/// catalog is never forced into pages it doesn't need. 12 matches the
/// original reference design's default; the rest give room to see
/// more per page without leaving pagination behind entirely.
const List<int?> kProductCatalogPageSizeOptions = [12, 24, 48, null];
const int kProductCatalogDefaultPageSize = 12;

/// Everything the catalog view currently wants to see - search,
/// category/group, status, sort, and pagination - independent of how
/// that's actually fulfilled. Immutable; use copyWith to change one
/// field (e.g. a new search term) while keeping the rest as they were.
class ProductCatalogQuery {
  final String searchQuery;
  final String selectedGroup; // 'All' or a kProductCategoryGroups key
  final String selectedCategory; // 'All' or a specific category
  final String selectedStatus; // 'All' | 'Active' | 'Low Stock' | 'Depleted' | 'Expired'
  final ProductSortOption sortOption;
  final int page; // 1-based
  final int? pageSize; // null = show all, no pagination

  const ProductCatalogQuery({
    this.searchQuery = '',
    this.selectedGroup = 'All',
    this.selectedCategory = 'All',
    this.selectedStatus = 'All',
    this.sortOption = ProductSortOption.nameAsc,
    this.page = 1,
    this.pageSize = kProductCatalogDefaultPageSize,
  });

  ProductCatalogQuery copyWith({
    String? searchQuery,
    String? selectedGroup,
    String? selectedCategory,
    String? selectedStatus,
    ProductSortOption? sortOption,
    int? page,
    // Distinguishes "not passed" from "explicitly set to null (show
    // all)" - a plain `int? pageSize` parameter can't tell those apart
    // on its own, since both look like "leave pageSize alone" to a
    // simple `pageSize ?? this.pageSize`.
    bool clearPageSize = false,
    int? pageSize,
  }) {
    return ProductCatalogQuery(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      sortOption: sortOption ?? this.sortOption,
      page: page ?? this.page,
      pageSize: clearPageSize ? null : (pageSize ?? this.pageSize),
    );
  }
}

/// The result of running a ProductCatalogQuery - the page of items to
/// actually render, plus enough metadata to drive pagination controls
/// (or to hide them entirely when there's only one page).
class ProductCatalogResult {
  final List<Product> items;
  final int totalCount; // matching the filters, before pagination
  final int totalPages;
  final int currentPage;

  const ProductCatalogResult({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });

  bool get needsPaginationControls => totalPages > 1;
}

/// Runs a ProductCatalogQuery against an already-loaded product list,
/// entirely client-side - search, category/group, status (computed
/// live via statusResolver, since status isn't a stored Firestore
/// field, just derived from stock and expiry at render time), sorting,
/// and pagination, all performed here rather than scattered across
/// each screen's own build() method.
///
/// Kept as a single, explicit entry point (run()) specifically so
/// that if a facility's catalog eventually grows large enough that
/// loading everything into memory stops being practical, only this
/// class's internals need to change - swapped for real Firestore
/// queries (where/orderBy/limit/startAfter, or a search index) -
/// without touching any screen. Every screen only ever builds a
/// ProductCatalogQuery and renders whatever ProductCatalogResult comes
/// back; none of them filter, sort, or paginate a product list
/// directly themselves.
class ProductCatalogService {
  static ProductCatalogResult run({
    required ProductCatalogQuery query,
    required List<Product> allProducts,
    // Each screen's own "does this belong here at all" rule (Sellable
    // Products: sellableQty > 0; Stock Store: stockQty > 0) - passed
    // in rather than hardcoded here, since the two screens genuinely
    // disagree about it and always will.
    required bool Function(Product product) belongsOnThisScreen,
    // A fully depleted product (nothing left anywhere) would fail
    // every belongsOnThisScreen check above by definition - let
    // through here specifically when the Depleted filter is selected,
    // so it stays reachable for traceability rather than being
    // permanently invisible on both catalog screens.
    required bool Function(Product product) isDepleted,
    required Map<String, dynamic> Function(Product product) statusResolver,
  }) {
    // ---- base set: what this screen shows at all ----
    // A fully depleted product is let through when the Depleted status
    // is specifically selected, or when "All" is selected - "All"
    // genuinely means everything, including Depleted, matching what
    // most people expect that word to mean. It's still not shown by
    // default under any of the OTHER status filters (Active/Low
    // Stock/Expired), only under "All" or "Depleted" themselves.
    final base = allProducts.where((p) {
      if (isDepleted(p)) return query.selectedStatus == 'Depleted' || query.selectedStatus == 'All';
      return belongsOnThisScreen(p);
    });

    // ---- search / category / group / status ----
    final searchLower = query.searchQuery.trim().toLowerCase();
    final filtered = base.where((p) {
      final matchesSearch = searchLower.isEmpty ||
          p.name.toLowerCase().contains(searchLower) ||
          (p.description ?? '').toLowerCase().contains(searchLower) ||
          (p.batchNo ?? '').toLowerCase().contains(searchLower);

      final category = p.category.isNotEmpty ? p.category : 'Uncategorized';
      final matchesCategory = query.selectedCategory == 'All' || category == query.selectedCategory;
      final matchesGroup =
          query.selectedGroup == 'All' || groupOfCategory(category) == query.selectedGroup;

      final matchesStatus =
          query.selectedStatus == 'All' || statusResolver(p)['text'] == query.selectedStatus;

      return matchesSearch && matchesCategory && matchesGroup && matchesStatus;
    }).toList();

    // ---- sort ----
    filtered.sort((a, b) {
      switch (query.sortOption) {
        case ProductSortOption.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ProductSortOption.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case ProductSortOption.priceLowHigh:
          return a.sellPrice.compareTo(b.sellPrice);
        case ProductSortOption.priceHighLow:
          return b.sellPrice.compareTo(a.sellPrice);
        case ProductSortOption.stockLowHigh:
          return a.sellableQty.compareTo(b.sellableQty);
        case ProductSortOption.stockHighLow:
          return b.sellableQty.compareTo(a.sellableQty);
        case ProductSortOption.expirySoonestFirst:
          // No expiry set sorts last - treated as "nothing urgent
          // here", not "most urgent of all" the way a null-as-earliest
          // comparison would otherwise imply.
          if (a.expiry == null && b.expiry == null) return 0;
          if (a.expiry == null) return 1;
          if (b.expiry == null) return -1;
          return a.expiry!.compareTo(b.expiry!);
      }
    });

    final totalCount = filtered.length;

    // ---- paginate ----
    if (query.pageSize == null) {
      return ProductCatalogResult(
        items: filtered,
        totalCount: totalCount,
        totalPages: 1,
        currentPage: 1,
      );
    }

    final pageSize = query.pageSize!;
    final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    final currentPage = query.page.clamp(1, totalPages);
    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = start >= totalCount ? <Product>[] : filtered.sublist(start, end);

    return ProductCatalogResult(
      items: pageItems,
      totalCount: totalCount,
      totalPages: totalPages,
      currentPage: currentPage,
    );
  }
}
