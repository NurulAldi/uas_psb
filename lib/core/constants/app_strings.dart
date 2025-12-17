/// Centralized Application Strings in Bahasa Indonesia
/// All user-facing text should be defined here for consistency and maintainability
class AppStrings {
  // Private constructor to prevent instantiation
  AppStrings._();

  // ============================================================================
  // GENERAL
  // ============================================================================
  static const String appName = 'RentLens';
  static const String loading = 'Memuat...';
  static const String retry = 'Coba Lagi';
  static const String cancel = 'Batal';
  static const String ok = 'OK';
  static const String save = 'Simpan';
  static const String delete = 'Hapus';
  static const String edit = 'Edit';
  static const String update = 'Perbarui';
  static const String submit = 'Kirim';
  static const String confirm = 'Konfirmasi';
  static const String yes = 'Ya';
  static const String no = 'Tidak';
  static const String close = 'Tutup';
  static const String back = 'Kembali';
  static const String next = 'Selanjutnya';
  static const String finish = 'Selesai';
  static const String skip = 'Lewati';
  static const String search = 'Cari';
  static const String filter = 'Filter';
  static const String refresh = 'Perbarui';
  static const String or = 'atau';

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  // Login Screen
  static const String loginWelcomeBack = 'Selamat Datang Kembali';
  static const String loginSubtitle =
      'Masuk untuk melanjutkan sewa kamera Anda';
  static const String email = 'Email';
  static const String emailHint = 'Masukkan email Anda';
  static const String password = 'Kata Sandi';
  static const String passwordHint = 'Masukkan kata sandi Anda';
  static const String login = 'Masuk';
  static const String noAccount = 'Belum punya akun? ';
  static const String registerNow = 'Daftar';
  static const String logout = 'Keluar';

  // Register Screen
  static const String registerTitle = 'Buat Akun';
  static const String registerSubtitle = 'Daftar untuk mulai menyewa kamera';
  static const String fullName = 'Nama Lengkap';
  static const String fullNameHint = 'Masukkan nama lengkap Anda';
  static const String phoneNumber = 'Nomor Telepon';
  static const String phoneNumberHint = 'Masukkan nomor telepon Anda';
  static const String phoneNumberOptional = 'Nomor Telepon (opsional)';
  static const String confirmPassword = 'Konfirmasi Kata Sandi';
  static const String confirmPasswordHint = 'Masukkan kembali kata sandi Anda';
  static const String register = 'Daftar';
  static const String alreadyHaveAccount = 'Sudah punya akun? ';
  static const String loginNow = 'Masuk';

  // Email Verification
  static const String verifyEmailTitle = 'Verifikasi Email Anda';
  static const String verifyEmailMessage =
      'Silakan cek email Anda untuk memverifikasi akun sebelum masuk.';
  static const String goToLogin = 'Ke Halaman Login';

  // Account Status
  static const String accountBanned = 'Akun Diblokir';
  static const String accountBannedMessage =
      'Akun Anda telah diblokir oleh administrator.';
  static const String contactAdminMessage =
      'Silakan hubungi administrator untuk informasi lebih lanjut.';

  // Validation Messages
  static const String emailRequired = 'Email wajib diisi';
  static const String emailInvalid = 'Masukkan email yang valid';
  static const String passwordRequired = 'Kata sandi wajib diisi';
  static const String passwordMinLength = 'Kata sandi minimal 6 karakter';
  static const String passwordsNotMatch = 'Kata sandi tidak cocok';
  static const String fullNameRequired = 'Nama lengkap wajib diisi';
  static const String phoneInvalid = 'Nomor telepon tidak valid';

  // ============================================================================
  // PROFILE
  // ============================================================================

  static const String profile = 'Profil';
  static const String editProfile = 'Edit Profil';
  static const String publicProfile = 'Profil Publik';
  static const String myProfile = 'Profil Saya';
  static const String updateProfile = 'Perbarui Profil';
  static const String profileUpdated = 'Profil berhasil diperbarui';
  static const String profileUpdateFailed = 'Gagal memperbarui profil';
  static const String changeAvatar = 'Ubah Foto Profil';
  static const String uploadAvatar = 'Unggah Foto Profil';
  static const String removeAvatar = 'Hapus Foto Profil';

  // Profile Fields
  static const String bio = 'Bio';
  static const String bioHint = 'Ceritakan tentang diri Anda';
  static const String bioOptional = 'Bio (opsional)';
  static const String address = 'Alamat';
  static const String addressHint = 'Masukkan alamat Anda';
  static const String addressOptional = 'Alamat (opsional)';
  static const String city = 'Kota';
  static const String cityHint = 'Masukkan nama kota Anda';
  static const String province = 'Provinsi';
  static const String provinceHint = 'Masukkan nama provinsi';
  static const String postalCode = 'Kode Pos';
  static const String postalCodeHint = 'Masukkan kode pos';

  // ============================================================================
  // LOCATION
  // ============================================================================

  static const String locationPermission = 'Izin Lokasi';
  static const String locationPermissionRequired = 'Izin lokasi diperlukan';
  static const String locationPermissionDenied = 'Izin lokasi ditolak';
  static const String locationPermissionPermanentlyDenied =
      'Izin lokasi ditolak permanen';
  static const String enableLocation = 'Aktifkan Lokasi';
  static const String locationRequired = 'Lokasi Diperlukan';
  static const String requestLocationPermission = 'Minta Izin Lokasi';
  static const String openSettings = 'Buka Pengaturan';
  static const String locationSetupTitle = 'Pengaturan Lokasi';
  static const String locationSetupMessage =
      'Kami memerlukan akses lokasi Anda untuk menampilkan produk terdekat.';
  static const String allowLocationAccess = 'Izinkan Akses Lokasi';
  static const String locationPermissionBannerTitle = 'Izinkan Akses Lokasi';
  static const String locationPermissionBannerMessage =
      'Untuk menemukan kamera terdekat, berikan izin akses lokasi.';
  static const String locationPermissionBannerPermanent =
      'Izin lokasi ditolak. Buka pengaturan untuk mengaktifkan.';
  static const String nearbyProducts = 'Produk Terdekat';
  static const String nearbyProductsInCity = 'Produk Terdekat di';
  static const String within = 'dalam radius';
  static const String kmRadius = 'km';
  static const String adjustRadius = 'Sesuaikan Radius';
  static const String adjustRadiusTitle = 'Sesuaikan Radius Pencarian';
  static const String selectRadius = 'Pilih radius pencarian (km):';
  static const String noNearbyProducts = 'Tidak Ada Produk Terdekat';
  static const String noNearbyProductsMessage =
      'Tidak ada produk tersedia dalam radius yang dipilih.';
  static const String tryIncreaseRadius =
      'Coba perluas radius pencarian atau cek lagi nanti.';
  static const String increaseRadius = 'Perluas Radius';

  // ============================================================================
  // PRODUCTS
  // ============================================================================

  static const String products = 'Produk';
  static const String myListings = 'Daftar Produk Saya';
  static const String myProducts = 'Produk Saya';
  static const String addProduct = 'Tambah Produk';
  static const String addNewProduct = 'Tambah Produk Baru';
  static const String editProduct = 'Edit Produk';
  static const String deleteProduct = 'Hapus Produk';
  static const String deleteProductConfirmation =
      'Apakah Anda yakin ingin menghapus produk ini?';
  static const String productDeleted = 'Produk berhasil dihapus';
  static const String productDeleteFailed = 'Gagal menghapus produk';
  static const String productAdded = 'Produk berhasil ditambahkan';
  static const String productUpdated = 'Produk berhasil diperbarui';
  static const String productAddFailed = 'Gagal menambahkan produk';
  static const String productUpdateFailed = 'Gagal memperbarui produk';
  static const String viewDetails = 'Lihat Detail';
  static const String productDetails = 'Detail Produk';
  static const String availableProducts = 'Produk Tersedia';
  static const String noProducts = 'Belum Ada Produk';
  static const String noProductsMessage = 'Belum ada produk tersedia saat ini.';
  static const String searchProducts = 'Cari produk...';
  static const String searchNearbyProducts = 'Cari kamera terdekat...';

  // Product Fields
  static const String productName = 'Nama Produk';
  static const String productNameHint = 'Masukkan nama produk';
  static const String productNameRequired = 'Nama produk wajib diisi';
  static const String description = 'Deskripsi';
  static const String descriptionHint = 'Deskripsikan produk Anda';
  static const String descriptionOptional = 'Deskripsi (opsional)';
  static const String category = 'Kategori';
  static const String selectCategory = 'Pilih Kategori';
  static const String categoryRequired = 'Kategori wajib dipilih';
  static const String pricePerDay = 'Harga per Hari';
  static const String pricePerDayHint = 'Masukkan harga sewa per hari';
  static const String priceRequired = 'Harga wajib diisi';
  static const String priceInvalid = 'Harga harus lebih dari 0';
  static const String priceFormat = 'Rp';
  static const String perDay = '/hari';
  static const String images = 'Gambar';
  static const String uploadImages = 'Unggah Gambar';
  static const String selectImages = 'Pilih Gambar';
  static const String imagesOptional = 'Gambar (opsional)';
  static const String maxImagesReached =
      'Maksimal 5 gambar. Beberapa gambar dilewati.';
  static const String imageUploadFailed = 'Gagal mengunggah gambar';
  static const String imagePickFailed = 'Gagal memilih gambar';
  static const String removeImage = 'Hapus Gambar';
  static const String available = 'Tersedia';
  static const String notAvailable = 'Tidak Tersedia';
  static const String availability = 'Ketersediaan';
  static const String owner = 'Pemilik';
  static const String contactOwner = 'Hubungi Pemilik';
  static const String viewOwnerProfile = 'Lihat Profil Pemilik';

  // Categories
  static const String categoryDSLR = 'DSLR';
  static const String categoryMirrorless = 'Mirrorless';
  static const String categoryActionCam = 'Action Camera';
  static const String categoryLens = 'Lensa';
  static const String categoryAccessories = 'Aksesoris';
  static const String categoryOther = 'Lainnya';
  static const String allCategories = 'Semua Kategori';

  // Distance
  static const String distance = 'Jarak';
  static const String awayFrom = 'dari lokasi Anda';
  static const String lessThan1km = '< 1 km';

  // ============================================================================
  // BOOKING
  // ============================================================================

  static const String booking = 'Booking';
  static const String bookNow = 'Booking Sekarang';
  static const String myBookings = 'Pesanan Saya';
  static const String bookingRequests = 'Permintaan Booking';
  static const String bookingHistory = 'Riwayat Booking';
  static const String bookingDetails = 'Detail Booking';
  static const String createBooking = 'Buat Booking';
  static const String bookingCreated = 'Booking berhasil dibuat';
  static const String bookingCreateFailed = 'Gagal membuat booking';
  static const String bookingUpdated = 'Booking berhasil diperbarui';
  static const String bookingUpdateFailed = 'Gagal memperbarui booking';
  static const String bookingCancelled = 'Booking dibatalkan';
  static const String bookingCancelFailed = 'Gagal membatalkan booking';
  static const String cancelBooking = 'Batalkan Booking';
  static const String cancelBookingConfirmation =
      'Apakah Anda yakin ingin membatalkan booking ini?';
  static const String noBookings = 'Belum Ada Booking';
  static const String noBookingsMessage =
      'Anda belum memiliki booking saat ini.';
  static const String ownerBookingManagement = 'Kelola Booking Masuk';
  static const String acceptBooking = 'Terima Booking';
  static const String rejectBooking = 'Tolak Booking';
  static const String completeBooking = 'Selesaikan Booking';

  // Booking Fields
  static const String startDate = 'Tanggal Mulai';
  static const String endDate = 'Tanggal Selesai';
  static const String selectStartDate = 'Pilih tanggal mulai';
  static const String selectEndDate = 'Pilih tanggal selesai';
  static const String dateRequired = 'Tanggal wajib dipilih';
  static const String endDateMustBeAfterStart =
      'Tanggal selesai harus setelah tanggal mulai';
  static const String rentalPeriod = 'Periode Sewa';
  static const String days = 'hari';
  static const String totalPrice = 'Total Harga';
  static const String notes = 'Catatan';
  static const String notesHint = 'Tambahkan catatan (opsional)';
  static const String notesOptional = 'Catatan (opsional)';
  static const String renter = 'Penyewa';
  static const String bookingDate = 'Tanggal Booking';

  // Booking Status
  static const String status = 'Status';
  static const String statusPending = 'Menunggu';
  static const String statusApproved = 'Disetujui';
  static const String statusRejected = 'Ditolak';
  static const String statusCancelled = 'Dibatalkan';
  static const String statusCompleted = 'Selesai';
  static const String statusInProgress = 'Berlangsung';
  static const String statusReturned = 'Dikembalikan';

  // Booking Timeline
  static const String bookingTimeline = 'Alur Booking';
  static const String timelineCreated = 'Booking Dibuat';
  static const String timelineApproved = 'Disetujui oleh Pemilik';
  static const String timelineRejected = 'Ditolak oleh Pemilik';
  static const String timelineCancelled = 'Dibatalkan';
  static const String timelineInProgress = 'Masa Sewa Berlangsung';
  static const String timelineCompleted = 'Booking Selesai';
  static const String timelineReturned = 'Produk Dikembalikan';

  // ============================================================================
  // PAYMENT
  // ============================================================================

  static const String payment = 'Pembayaran';
  static const String payNow = 'Bayar Sekarang';
  static const String paymentMethod = 'Metode Pembayaran';
  static const String selectPaymentMethod = 'Pilih Metode Pembayaran';
  static const String qris = 'QRIS';
  static const String bankTransfer = 'Transfer Bank';
  static const String eWallet = 'E-Wallet';
  static const String paymentStatus = 'Status Pembayaran';
  static const String paymentPending = 'Menunggu Pembayaran';
  static const String paymentSuccess = 'Pembayaran Berhasil';
  static const String paymentFailed = 'Pembayaran Gagal';
  static const String paymentCancelled = 'Pembayaran Dibatalkan';
  static const String paymentExpired = 'Pembayaran Kedaluwarsa';
  static const String paymentRefunded = 'Pembayaran Dikembalikan';
  static const String paymentProcessing = 'Memproses Pembayaran';
  static const String paymentDetails = 'Detail Pembayaran';
  static const String paymentAmount = 'Jumlah Pembayaran';
  static const String paymentConfirmation = 'Konfirmasi Pembayaran';
  static const String scanQRCode = 'Pindai Kode QR';
  static const String copyCode = 'Salin Kode';
  static const String codeCopied = 'Kode berhasil disalin';

  // ============================================================================
  // ADMIN
  // ============================================================================

  static const String adminDashboard = 'Dashboard Admin';
  static const String adminPanel = 'Panel Admin';
  static const String userManagement = 'Kelola Pengguna';
  static const String reportManagement = 'Kelola Laporan';
  static const String statistics = 'Statistik';
  static const String totalUsers = 'Total Pengguna';
  static const String totalProducts = 'Total Produk';
  static const String totalBookings = 'Total Booking';
  static const String totalRevenue = 'Total Pendapatan';
  static const String activeUsers = 'Pengguna Aktif';
  static const String bannedUsers = 'Pengguna Diblokir';
  static const String reports = 'Laporan';
  static const String viewAllReports = 'Lihat Semua Laporan';
  static const String viewAllUsers = 'Lihat Semua Pengguna';
  static const String banUser = 'Blokir Pengguna';
  static const String unbanUser = 'Buka Blokir Pengguna';
  static const String banUserConfirmation =
      'Apakah Anda yakin ingin memblokir pengguna ini?';
  static const String unbanUserConfirmation =
      'Apakah Anda yakin ingin membuka blokir pengguna ini?';
  static const String userBanned = 'Pengguna berhasil diblokir';
  static const String userUnbanned = 'Pengguna berhasil dibuka blokirnya';
  static const String reportUser = 'Laporkan Pengguna';
  static const String reportProduct = 'Laporkan Produk';
  static const String reportReason = 'Alasan Laporan';
  static const String reportReasonHint = 'Jelaskan alasan laporan Anda';
  static const String reportReasonRequired = 'Alasan laporan wajib diisi';
  static const String reportSubmitted = 'Laporan berhasil dikirim';
  static const String reportSubmitFailed = 'Gagal mengirim laporan';
  static const String resolveReport = 'Selesaikan Laporan';
  static const String reportResolved = 'Laporan diselesaikan';
  static const String reportedBy = 'Dilaporkan oleh';
  static const String reportedItem = 'Item yang Dilaporkan';
  static const String reportDate = 'Tanggal Laporan';

  // ============================================================================
  // MENU & NAVIGATION
  // ============================================================================

  static const String home = 'Beranda';
  static const String settings = 'Pengaturan';
  static const String menu = 'Menu';
  static const String more = 'Lainnya';

  // ============================================================================
  // ERRORS & MESSAGES
  // ============================================================================

  static const String error = 'Kesalahan';
  static const String errorOccurred = 'Terjadi kesalahan';
  static const String errorTryAgain = 'Terjadi kesalahan. Silakan coba lagi.';
  static const String noInternetConnection = 'Tidak ada koneksi internet';
  static const String serverError = 'Kesalahan server';
  static const String notFound = 'Tidak ditemukan';
  static const String unauthorized = 'Tidak terotorisasi';
  static const String forbidden = 'Akses ditolak';
  static const String sessionExpired = 'Sesi berakhir. Silakan masuk kembali.';
  static const String userNotAuthenticated = 'Pengguna tidak terautentikasi';

  // Success Messages
  static const String success = 'Berhasil';
  static const String operationSuccess = 'Operasi berhasil';
  static const String dataSaved = 'Data berhasil disimpan';
  static const String dataDeleted = 'Data berhasil dihapus';
  static const String dataUpdated = 'Data berhasil diperbarui';

  // Empty States
  static const String noData = 'Tidak ada data';
  static const String noResults = 'Tidak ada hasil';
  static const String noResultsFound = 'Tidak ada hasil ditemukan';
  static const String tryDifferentSearch = 'Coba kata kunci pencarian lain';
  static const String emptyList = 'Daftar kosong';

  // Loading States
  static const String loadingData = 'Memuat data...';
  static const String pleaseWait = 'Mohon tunggu...';
  static const String processing = 'Memproses...';
  static const String uploading = 'Mengunggah...';
  static const String downloading = 'Mengunduh...';
  static const String saving = 'Menyimpan...';
  static const String deleting = 'Menghapus...';
  static const String updating = 'Memperbarui...';

  // Confirmation Messages
  static const String confirmAction = 'Konfirmasi Tindakan';
  static const String areYouSure = 'Apakah Anda yakin?';
  static const String cannotBeUndone = 'Tindakan ini tidak dapat dibatalkan.';
  static const String confirmDelete = 'Konfirmasi Hapus';
  static const String confirmCancel = 'Konfirmasi Batal';

  // Permissions
  static const String permissionDenied = 'Izin ditolak';
  static const String permissionRequired = 'Izin diperlukan';
  static const String grantPermission = 'Berikan Izin';

  // Network
  static const String connectionLost = 'Koneksi terputus';
  static const String reconnecting = 'Menghubungkan kembali...';
  static const String connected = 'Terhubung';

  // ============================================================================
  // FORMS & INPUTS
  // ============================================================================

  static const String required = 'Wajib diisi';
  static const String optional = 'Opsional';
  static const String select = 'Pilih';
  static const String selectDate = 'Pilih Tanggal';
  static const String selectTime = 'Pilih Waktu';
  static const String invalidInput = 'Input tidak valid';
  static const String fieldRequired = 'Field ini wajib diisi';
  static const String invalidFormat = 'Format tidak valid';

  // ============================================================================
  // DATE & TIME
  // ============================================================================

  static const String today = 'Hari Ini';
  static const String yesterday = 'Kemarin';
  static const String tomorrow = 'Besok';
  static const String thisWeek = 'Minggu Ini';
  static const String thisMonth = 'Bulan Ini';
  static const String lastMonth = 'Bulan Lalu';
  static const String date = 'Tanggal';
  static const String time = 'Waktu';

  // ============================================================================
  // ACTIONS
  // ============================================================================

  static const String view = 'Lihat';
  static const String add = 'Tambah';
  static const String create = 'Buat';
  static const String remove = 'Hapus';
  static const String send = 'Kirim';
  static const String share = 'Bagikan';
  static const String copy = 'Salin';
  static const String paste = 'Tempel';
  static const String clear = 'Hapus';
  static const String reset = 'Reset';
  static const String apply = 'Terapkan';
  static const String download = 'Unduh';
  static const String upload = 'Unggah';
  static const String selectAll = 'Pilih Semua';
  static const String deselectAll = 'Batalkan Semua Pilihan';

  // ============================================================================
  // MISC
  // ============================================================================

  static const String version = 'Versi';
  static const String aboutApp = 'Tentang Aplikasi';
  static const String termsAndConditions = 'Syarat dan Ketentuan';
  static const String privacyPolicy = 'Kebijakan Privasi';
  static const String helpAndSupport = 'Bantuan & Dukungan';
  static const String contactUs = 'Hubungi Kami';
  static const String feedback = 'Umpan Balik';
  static const String rateApp = 'Nilai Aplikasi';
  static const String shareApp = 'Bagikan Aplikasi';
  static const String language = 'Bahasa';
  static const String theme = 'Tema';
  static const String notifications = 'Notifikasi';
  static const String enableNotifications = 'Aktifkan Notifikasi';
  static const String disableNotifications = 'Nonaktifkan Notifikasi';

  // ============================================================================
  // ADDITIONAL UI TEXT
  // ============================================================================

  static const String goHome = 'Ke Beranda';
  static const String browseProducts = 'Jelajahi Produk';
  static const String allProducts = 'Semua Produk';
  static const String viewBooking = 'Lihat Booking';
  static const String startRental = 'Mulai Rental';
  static const String markCompleted = 'Tandai Selesai';
  static const String confirmOrder = 'Konfirmasi Pesanan';
  static const String bookingInfo = 'Informasi Booking';
  static const String deliveryInfo = 'Informasi Pengiriman';
  static const String priceBreakdown = 'Rincian Harga';
  static const String paymentInfo = 'Informasi Pembayaran';
  static const String deliveryAddress = 'Alamat Pengiriman';
  static const String deliveryMethod = 'Metode Pengiriman';
  static const String deliveryFee = 'Biaya Pengiriman';
  static const String rentalPrice = 'Harga Sewa';
  static const String rentNow = 'Sewa Sekarang';
  static const String notAvailableShort = 'Tidak Tersedia';
  // NOTE: acceptBooking, rejectBooking, payNow, bookingHistory are defined above in BOOKING/PAYMENT sections
  static const String bookingRejected = 'Booking ditolak';
  static const String paymentCompleted = 'Pembayaran Selesai';
  static const String cancelOrder = 'Batalkan Pesanan';
  static const String unknownUser = 'Pengguna Tidak Dikenal';
  static const String productOwner = 'Pemilik Produk';
  static const String orderId = 'ID Pesanan';
  static const String noData2 = 'Tidak ada';
  static const String loadMore = 'Muat Lebih Banyak';
  static const String reload = 'Muat Ulang';
  static const String allStatus = 'Semua Status';
  static const String yourLocationPlaceholder = 'Lokasi Anda';
  static const String searchResults = 'Hasil Pencarian';
  static const String cameraInCategory = 'Kamera';
  static const String nearbyCamera = 'Kamera Terdekat';
  static const String productsFound = 'produk ditemukan dalam radius';
  static const String whyNeedThis = 'Mengapa kami membutuhkan ini?';
  static const String newBooking = 'Booking Baru';
  // bookingHistory is already declared above
  static const String bookingHistoryEmpty =
      'Riwayat booking Anda akan muncul di sini';
  static const String editProfileButton = 'Edit Profil';
  static const String removeProfilePicture = 'Hapus Foto Profil';
  static const String chooseImageSource = 'Pilih Sumber Foto';
  static const String camera = 'Kamera';
  static const String gallery = 'Galeri';
  static const String takeNewPhoto = 'Ambil foto baru';
  static const String chooseFromPhotos = 'Pilih dari foto Anda';
  static const String discardChanges = 'Buang Perubahan?';
  static const String unsavedChanges =
      'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar tanpa menyimpan?';
  static const String stay = 'Tetap';
  static const String discard = 'Buang';
  static const String imagePickFailedError = 'Gagal memilih gambar';
  static const String locationUpdated = 'Lokasi diperbarui';
  static const String cannotGetLocation = 'Tidak dapat mengambil lokasi';
  static const String userNotAuth = 'Pengguna tidak terautentikasi';

  // ============================================================================
  // ADDITIONAL LOCATION STRINGS
  // ============================================================================

  static const String loadingNearbyProducts = 'Memuat produk terdekat...';
  static const String gettingYourLocation = 'Mendapatkan lokasi Anda...';
  static const String couldNotGetLocation =
      'Tidak dapat mendapatkan lokasi Anda';
  static const String failedToCheckLocationPermission =
      'Gagal memeriksa izin lokasi';
  static const String failedToRequestLocationPermission =
      'Gagal meminta izin lokasi';
  static const String failedToLoadNearbyProducts =
      'Gagal memuat produk terdekat';
  static const String locationPermissionPermanentlyDeniedMessage =
      'Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi untuk menemukan kamera rental terdekat.';
  static const String locationPermissionMessage =
      'Kami memerlukan lokasi Anda untuk menampilkan kamera rental dalam radius 20km dari area Anda.';
  static const String aboutLocationAccessTitle = 'Tentang Akses Lokasi';
  static const String rentLensUsesLocation =
      'RentLens menggunakan lokasi Anda untuk:';
  static const String locationReason1 =
      'Menampilkan kamera tersedia di dekat Anda (dalam 20km)';
  static const String locationReason2 =
      'Menghitung jarak dan waktu pickup/return';
  static const String locationReason3 =
      'Menghubungkan Anda dengan pemilik terdekat untuk transaksi lebih cepat';
  static const String locationPrivacy =
      'Lokasi pasti Anda tidak pernah dibagikan ke orang lain';
  static const String locationPermissionChangeAnytime =
      'Anda dapat mengubah izin ini kapan saja di pengaturan perangkat Anda.';

  // ============================================================================
  // NO NEARBY PRODUCTS
  // ============================================================================

  static const String tryText = 'Coba:';
  static const String increasingSearchRadius = 'Perluas radius pencarian';
  static const String refreshingNewListings =
      'Perbarui untuk melihat listing baru';
  static const String checkingBackLater = 'Cek kembali nanti';
  static const String increaseRadiusTo = 'Perluas Radius ke';

  // ============================================================================
  // PRODUCT-SPECIFIC
  // ============================================================================

  static const String failedToLoadImage = 'Gagal memuat gambar';
  static const String failedToLoadProducts = 'Gagal memuat produk';
  static const String noProductsInCategory = 'Tidak ada produk dalam kategori';
  static const String noProductsAvailableYet = 'Belum ada produk tersedia';
  static const String productNotFound = 'Produk tidak ditemukan';
  static const String productNotFoundMessage =
      'Produk yang Anda cari tidak ada';
  static const String thisIsYourProduct = 'Ini adalah listing produk Anda';
  static const String unavailable = 'Tidak Tersedia';
  static const String availableForRent = 'Tersedia untuk disewa';
  static const String currentlyNotAvailable = 'Sedang tidak tersedia';
  static const String noListingsYet = 'Belum ada listing';
  static const String addProductTooltip = 'Tambah Produk';

  // ============================================================================
  // BOOKING-SPECIFIC
  // ============================================================================

  static const String selectStartDateFirst =
      'Silakan pilih tanggal mulai terlebih dahulu';
  static const String pleaseSelectRentalDates = 'Silakan pilih tanggal rental';
  static const String confirmBookingTitle = 'Konfirmasi Booking';
  static const String confirmBookingMessage =
      'Apakah Anda yakin ingin melanjutkan booking ini?';
  static const String bookingNotFound = 'Booking tidak ditemukan';
  static const String bookingExpired = 'Booking kedaluwarsa';

  // ============================================================================
  // PAYMENT-SPECIFIC
  // ============================================================================

  static const String paymentNotFound = 'Pembayaran tidak ditemukan';
  static const String totalAmount = 'Total Jumlah';
  static const String paymentExpiresIn = 'Pembayaran Kedaluwarsa Dalam:';
  static const String paymentMethodLabel = 'Metode Pembayaran';
  static const String confirmPaymentInYourApp =
      'Konfirmasi pembayaran di aplikasi Anda';
  static const String cancelPayment = 'Batalkan Pembayaran';
  static const String paymentError = 'Kesalahan Pembayaran';
  static const String paymentSuccessful = 'Pembayaran Berhasil!';
  static const String productRental = 'Sewa Produk';

  // Payment Status (for display)
  static const String paymentStatusPending = 'Menunggu';
  static const String paymentStatusProcessing = 'Diproses';
  static const String paymentStatusPaid = 'Terbayar';
  static const String paymentStatusFailed = 'Gagal';
  static const String paymentStatusExpired = 'Kedaluwarsa';
  static const String paymentStatusCancelled = 'Dibatalkan';

  // Payment Status Description
  static const String waitingForPayment = 'Menunggu pembayaran';
  static const String paymentBeingProcessed = 'Pembayaran sedang diproses';
  static const String paymentSuccessDescription = 'Pembayaran berhasil';
  static const String paymentFailedDescription = 'Pembayaran gagal';
  static const String paymentLinkExpired = 'Link pembayaran kedaluwarsa';
  static const String paymentCancelledDescription = 'Pembayaran dibatalkan';

  // ============================================================================
  // ADDITIONAL BOOKING STRINGS
  // ============================================================================

  static const String bookingSubmittedSuccessfully =
      'Booking berhasil dikirim!';
  static const String processingPayment = 'Memproses pembayaran...';
  static const String preparingPayment = 'Menyiapkan pembayaran...';
  static const String cancelBookingQuestion = 'Batalkan Booking?';
  static const String yesCancelIt = 'Ya, Batalkan';
  static const String bookingSuccessfullyCancelled =
      'Booking berhasil dibatalkan';
  static const String acceptBookingQuestion = 'Terima Booking?';
  static const String accept = 'Terima';
  static const String bookingAccepted = 'Booking diterima!';
  static const String rejectBookingQuestion = 'Tolak Booking?';
  static const String bookingRejectedMessage = 'Booking ditolak';
  static const String startRentalQuestion = 'Mulai Rental?';
  static const String start = 'Mulai';
  static const String rentalStarted = 'Rental dimulai!';
  static const String completeRentalQuestion = 'Selesaikan Rental?';
  static const String complete = 'Selesai';
  static const String rentalCompleted = 'Rental selesai!';
  static const String loadingPaymentStatus = 'Memuat status pembayaran...';
  static const String tapPlusButtonToAdd =
      'Ketuk tombol + untuk menambah produk pertama Anda';

  // ============================================================================
  // AUTH & PROFILE SPECIFIC
  // ============================================================================

  static const String userProfile = 'Profil Pengguna';
  static const String userNotFoundMessage = 'Pengguna tidak ditemukan';
  static const String pleaseGetLocationFirst =
      'Silakan dapatkan lokasi Anda terlebih dahulu';
  static const String locationSavedSuccessfully = 'Lokasi berhasil disimpan!';
  static const String errorSavingLocation = 'Kesalahan menyimpan lokasi';
  static const String openLocationSettings = 'Buka Pengaturan Lokasi';
  static const String skipLocationSetup = 'Lewati Pengaturan Lokasi?';
  static const String skipAnyway = 'Lewati Saja';
  static const String skipForNow = 'Lewati untuk sekarang';
  static const String profileUpdatedSuccessfully =
      'Profil berhasil diperbarui!';
  static const String locationUpdatedCity = 'Lokasi diperbarui';
  static const String failedToPickImage = 'Gagal memilih gambar';

  // ============================================================================
  // ADMIN SPECIFIC
  // ============================================================================

  static const String reportSubmittedSuccessfully = 'Laporan berhasil dikirim';
  static const String failedToSubmitReport = 'Gagal mengirim laporan';
  static const String submitReport = 'Kirim Laporan';
  static const String banUserTitle = 'Blokir Pengguna';
  static const String ban = 'Blokir';
  static const String provideReason = 'Silakan berikan alasan';
  static const String userBannedSuccessfully = 'Pengguna berhasil diblokir';
  static const String failedToBanUser = 'Gagal memblokir pengguna';
  static const String unbanUserTitle = 'Buka Blokir Pengguna';
  static const String areYouSureUnban =
      'Apakah Anda yakin ingin membuka blokir';
  static const String unban = 'Buka Blokir';
  static const String userUnbannedSuccessfully =
      'Pengguna berhasil dibuka blokirnya';
  static const String failedToUnbanUser = 'Gagal membuka blokir pengguna';
  static const String noUsersFound = 'Tidak ada pengguna ditemukan';
  static const String phone = 'Telepon';

  // ============================================================================
  // VALIDATION & ERRORS
  // ============================================================================

  static const String noAuthenticatedUser = 'Tidak ada pengguna terautentikasi';
  static const String noUpdatesProvided = 'Tidak ada pembaruan yang diberikan';
  static const String failedToUploadImage = 'Gagal mengunggah gambar';
  static const String failedToUploadAnyImages =
      'Gagal mengunggah gambar apapun';

  // ============================================================================
  // USER/OWNER
  // ============================================================================

  static const String unknown = 'Tidak diketahui';
  static const String user = 'Pengguna';

  // ============================================================================
  // MISC ACTIONS
  // ============================================================================

  static const String adjust = 'Sesuaikan';
  static const String viewAllProducts = 'Lihat Semua Produk';
}
