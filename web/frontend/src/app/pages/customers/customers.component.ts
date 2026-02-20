import { CommonModule } from '@angular/common';
import { Location } from '@angular/common';
import {
  AfterViewInit,
  Component,
  ElementRef,
  HostListener,
  NgZone,
  OnDestroy,
  OnInit,
  ViewChild
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { APP_CONFIG } from '../../core/config';
import { DebtService } from '../../core/debt.service';
import { Customer, CustomerImage } from '../../models/customer.model';

type CustomerStatusFilter = 'all' | 'active' | 'inactive';
type CustomerViewTab = 'list' | 'map';

interface CustomerView extends Customer {
  avatarUrl: string | null;
}

interface CustomerFormModel {
  name: string;
  phone: string;
  address: string;
  latitude: string;
  longitude: string;
  is_active: boolean;
}

interface UnshortenResponse {
  success?: boolean;
  resolved_url?: string;
  error?: string;
}

interface CustomerCoordinatePoint {
  customer: CustomerView;
  lat: number;
  lng: number;
}

declare global {
  interface Window {
    google?: any;
  }
}

@Component({
  selector: 'app-customers',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './customers.component.html',
  styleUrl: './customers.component.scss'
})
export class CustomersComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild('googleMapCanvas') googleMapCanvas?: ElementRef<HTMLDivElement>;
  @ViewChild('overviewMapCanvas') overviewMapCanvas?: ElementRef<HTMLDivElement>;
  private static googleMapsScriptPromise: Promise<void> | null = null;

  customers: CustomerView[] = [];
  searchTerm = '';
  statusFilter: CustomerStatusFilter = 'active';
  activeTab: CustomerViewTab = 'list';
  isOverviewMapExpanded = false;
  showForm = false;
  isLoading = false;
  errorMessage = '';
  googleMapError = '';
  overviewMapError = '';
  isResolvingMapLink = false;
  mapsLinkInput = '';
  editingCustomer: Customer | null = null;
  showImageManager = false;
  imageManagerCustomer: CustomerView | null = null;
  customerImages: CustomerImage[] = [];
  isLoadingImages = false;
  isUploadingImages = false;
  isUpdatingAvatar = false;
  imageManagerError = '';
  readonly maxCustomerImages = 20;
  readonly hasGoogleMapsApiKey = !!APP_CONFIG.googleMapsApiKey?.trim();
  private mapInstance: any = null;
  private mapMarker: any = null;
  private overviewMapInstance: any = null;
  private overviewMapInfoWindow: any = null;
  private overviewMarkers: any[] = [];
  private overviewMarkerByCustomerId = new Map<string, any>();
  private readonly defaultLatitude = 10.121973;
  private readonly defaultLongitude = 105.279663;
  private hasImageChanges = false;

  customerForm: CustomerFormModel = this.createEmptyForm();

  constructor(
    private debt: DebtService,
    private router: Router,
    private location: Location,
    private ngZone: NgZone
  ) {}

  ngOnInit(): void {
    this.loadCustomers();
  }

  ngAfterViewInit(): void {
    if (!this.hasGoogleMapsApiKey || this.activeTab !== 'map') {
      return;
    }
    void this.refreshOverviewMap();
  }

  ngOnDestroy(): void {
    this.disposeOverviewMap();
  }

  @HostListener('window:keydown.escape')
  onEscapeKey(): void {
    if (this.isOverviewMapExpanded) {
      this.toggleOverviewMapExpanded(false);
    }
  }

  loadCustomers(): void {
    this.isLoading = true;
    this.errorMessage = '';

    this.debt.getCustomers(false, true).subscribe({
      next: (data) => {
        this.customers = data.map((customer) => this.toCustomerView(customer));
        void this.refreshOverviewMap();
        this.isLoading = false;
      },
      error: () => {
        this.customers = [];
        this.clearOverviewMarkers();
        this.errorMessage = 'Không thể tải danh sách khách hàng.';
        this.isLoading = false;
      }
    });
  }

  get filteredCustomers(): CustomerView[] {
    const query = this.searchTerm.toLowerCase().trim();

    return this.customers.filter((customer) => {
      const matchesQuery =
        !query ||
        customer.name.toLowerCase().includes(query) ||
        (customer.phone ?? '').includes(query);

      const matchesStatus =
        this.statusFilter === 'all'
          ? true
          : this.statusFilter === 'active'
            ? customer.is_active !== false
            : customer.is_active === false;

      return matchesQuery && matchesStatus;
    });
  }

  get activeCount(): number {
    return this.customers.filter((customer) => customer.is_active !== false).length;
  }

  get inactiveCount(): number {
    return this.customers.filter((customer) => customer.is_active === false).length;
  }

  get hasFilters(): boolean {
    return this.searchTerm.trim().length > 0 || this.statusFilter !== 'active';
  }

  get customersWithCoordinates(): CustomerView[] {
    return this.customers.filter((customer) => this.toCoordinatePoint(customer) !== null);
  }

  get filteredCustomersWithCoordinates(): CustomerView[] {
    return this.filteredCustomers.filter((customer) => this.toCoordinatePoint(customer) !== null);
  }

  get isImageLimitReached(): boolean {
    return this.customerImages.length >= this.maxCustomerImages;
  }

  get remainingImageSlots(): number {
    return Math.max(0, this.maxCustomerImages - this.customerImages.length);
  }

  goBack(): void {
    this.location.back();
  }

  goHome(): void {
    this.router.navigateByUrl('/');
  }

  clearFilters(): void {
    this.searchTerm = '';
    this.statusFilter = 'active';
    void this.refreshOverviewMap();
  }

  setStatusFilter(filter: CustomerStatusFilter): void {
    this.statusFilter = filter;
    void this.refreshOverviewMap();
  }

  onSearchTermChanged(): void {
    void this.refreshOverviewMap();
  }

  refreshOverviewMapManually(): void {
    void this.refreshOverviewMap();
  }

  toggleOverviewMapExpanded(force?: boolean): void {
    const nextState = typeof force === 'boolean' ? force : !this.isOverviewMapExpanded;
    this.setOverviewExpandedState(nextState);

    if (this.activeTab !== 'map') {
      return;
    }

    void this.waitForDialogPaint().then(() => {
      if (this.overviewMapInstance) {
        window.google?.maps?.event?.trigger?.(this.overviewMapInstance, 'resize');
      }
      void this.refreshOverviewMap();
    });
  }

  setActiveTab(tab: CustomerViewTab): void {
    if (this.activeTab === tab) {
      if (tab === 'map') {
        void this.refreshOverviewMap();
      }
      return;
    }

    const previousTab = this.activeTab;
    this.activeTab = tab;

    if (previousTab === 'map' && tab !== 'map') {
      this.setOverviewExpandedState(false);
      this.disposeOverviewMap();
      return;
    }

    if (tab === 'map') {
      void this.waitForDialogPaint().then(() => this.refreshOverviewMap());
    }
  }

  async openForm(customer?: Customer): Promise<void> {
    this.editingCustomer = customer ?? null;
    this.customerForm = customer ? this.toFormModel(customer) : this.createEmptyForm();
    this.googleMapError = '';
    this.mapsLinkInput = '';
    this.showForm = true;
    await this.initializeGoogleMap();
  }

  closeForm(): void {
    this.showForm = false;
    this.editingCustomer = null;
    this.customerForm = this.createEmptyForm();
    if (this.mapMarker?.setMap) {
      this.mapMarker.setMap(null);
    }
    this.mapInstance = null;
    this.mapMarker = null;
    this.googleMapError = '';
    this.mapsLinkInput = '';
  }

  saveCustomer(): void {
    const name = this.customerForm.name.trim();
    if (!name) {
      window.alert('Vui lòng nhập tên khách hàng.');
      return;
    }

    let latitude: number | null = null;
    let longitude: number | null = null;

    try {
      latitude = this.parseCoordinate(this.customerForm.latitude, 'latitude');
      longitude = this.parseCoordinate(this.customerForm.longitude, 'longitude');
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Tọa độ không hợp lệ.';
      window.alert(message);
      return;
    }

    if ((latitude === null) !== (longitude === null)) {
      window.alert('Vui lòng nhập đủ cả vĩ độ và kinh độ hoặc để trống cả hai.');
      return;
    }

    const payload = {
      name,
      phone: this.customerForm.phone.trim() || null,
      address: this.customerForm.address.trim() || null,
      latitude,
      longitude,
      is_active: this.customerForm.is_active
    };

    const request = this.editingCustomer
      ? this.debt.updateCustomer(this.editingCustomer.id, payload)
      : this.debt.createCustomer(payload);

    request.subscribe({
      next: () => {
        this.closeForm();
        this.loadCustomers();
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể lưu khách hàng.')
    });
  }

  deleteCustomer(customer: Customer): void {
    if (!confirm(`Ẩn khách hàng "${customer.name}"?`)) {
      return;
    }

    this.debt.deleteCustomer(customer.id).subscribe({
      next: () => this.loadCustomers(),
      error: (err) => window.alert(err?.error?.message || 'Không thể ẩn khách hàng.')
    });
  }

  openImageManager(customer: CustomerView): void {
    this.imageManagerCustomer = customer;
    this.showImageManager = true;
    this.customerImages = [];
    this.isLoadingImages = false;
    this.isUploadingImages = false;
    this.isUpdatingAvatar = false;
    this.imageManagerError = '';
    this.hasImageChanges = false;
    this.loadCustomerImages();
  }

  closeImageManager(): void {
    const shouldReloadCustomers = this.hasImageChanges;

    this.showImageManager = false;
    this.imageManagerCustomer = null;
    this.customerImages = [];
    this.isLoadingImages = false;
    this.isUploadingImages = false;
    this.isUpdatingAvatar = false;
    this.imageManagerError = '';
    this.hasImageChanges = false;

    if (shouldReloadCustomers) {
      this.loadCustomers();
    }
  }

  loadCustomerImages(): void {
    const customer = this.imageManagerCustomer;
    if (!customer) {
      return;
    }

    this.isLoadingImages = true;
    this.imageManagerError = '';

    this.debt.getCustomerImages(customer.id, true).subscribe({
      next: (data) => {
        this.customerImages = data;
        this.isLoadingImages = false;

        const avatarPath = customer.avatar_image_path?.trim();
        if (avatarPath && !data.some((item) => item.image_path === avatarPath)) {
          this.patchCustomerAvatar(customer.id, null);
        }
      },
      error: () => {
        this.customerImages = [];
        this.imageManagerError = 'Không thể tải danh sách ảnh khách hàng.';
        this.isLoadingImages = false;
      }
    });
  }

  async onImageFilesSelected(event: Event): Promise<void> {
    const customer = this.imageManagerCustomer;
    const input = event.target as HTMLInputElement | null;
    const files = Array.from(input?.files ?? []);

    if (input) {
      input.value = '';
    }

    if (!customer || files.length === 0 || this.isUploadingImages) {
      return;
    }

    if (this.isImageLimitReached) {
      window.alert(`Đã đạt tối đa ${this.maxCustomerImages} ảnh cho khách hàng này.`);
      return;
    }

    const uploadQueue = files.slice(0, this.remainingImageSlots);
    const skippedByLimit = files.length - uploadQueue.length;

    this.isUploadingImages = true;
    let uploadedCount = 0;
    let failedCount = 0;

    try {
      for (const file of uploadQueue) {
        if (!file || file.size <= 0) {
          failedCount += 1;
          continue;
        }

        try {
          await firstValueFrom(this.debt.uploadCustomerImage(customer.id, file));
          uploadedCount += 1;
        } catch {
          failedCount += 1;
        }
      }
    } finally {
      this.isUploadingImages = false;
    }

    if (uploadedCount > 0) {
      this.hasImageChanges = true;
      this.loadCustomerImages();
    }

    if (uploadedCount > 0) {
      window.alert(`Đã tải lên ${uploadedCount} ảnh.`);
    }

    if (skippedByLimit > 0) {
      window.alert(
        `Đã bỏ qua ${skippedByLimit} ảnh vì vượt giới hạn ${this.maxCustomerImages} ảnh/khách hàng.`
      );
    }

    if (failedCount > 0) {
      window.alert(`Có ${failedCount} ảnh tải lên thất bại.`);
    }
  }

  setImageAsAvatar(image: CustomerImage): void {
    const customer = this.imageManagerCustomer;
    if (!customer || this.isUpdatingAvatar || this.isAvatarImage(image)) {
      return;
    }

    this.isUpdatingAvatar = true;

    this.debt.setCustomerAvatar(customer.id, image.image_path).subscribe({
      next: () => {
        this.isUpdatingAvatar = false;
        this.hasImageChanges = true;
        this.patchCustomerAvatar(customer.id, image.image_path);
      },
      error: (error) => {
        this.isUpdatingAvatar = false;
        window.alert(this.resolveErrorMessage(error, 'Không thể đặt ảnh đại diện.'));
      }
    });
  }

  clearCustomerAvatar(): void {
    const customer = this.imageManagerCustomer;
    if (!customer || this.isUpdatingAvatar || !customer.avatar_image_path) {
      return;
    }

    this.isUpdatingAvatar = true;

    this.debt.setCustomerAvatar(customer.id, null).subscribe({
      next: () => {
        this.isUpdatingAvatar = false;
        this.hasImageChanges = true;
        this.patchCustomerAvatar(customer.id, null);
      },
      error: (error) => {
        this.isUpdatingAvatar = false;
        window.alert(this.resolveErrorMessage(error, 'Không thể gỡ ảnh đại diện.'));
      }
    });
  }

  deleteCustomerImage(image: CustomerImage): void {
    const customer = this.imageManagerCustomer;
    if (!customer) {
      return;
    }

    if (!window.confirm('Bạn có chắc muốn xóa ảnh này?')) {
      return;
    }

    this.debt.deleteCustomerImage(image.id).subscribe({
      next: () => {
        if (this.imageManagerCustomer?.avatar_image_path === image.image_path) {
          this.patchCustomerAvatar(customer.id, null);
        }
        this.hasImageChanges = true;
        this.loadCustomerImages();
      },
      error: (error) => {
        window.alert(this.resolveErrorMessage(error, 'Không thể xóa ảnh khách hàng.'));
      }
    });
  }

  openImagePreview(image: CustomerImage): void {
    window.open(this.customerImageUrl(image), '_blank', 'noopener,noreferrer');
  }

  openAvatarPreview(): void {
    const avatarPath = this.imageManagerCustomer?.avatar_image_path?.trim();
    if (!avatarPath) {
      return;
    }
    window.open(this.debt.getCustomerImagePublicUrl(avatarPath), '_blank', 'noopener,noreferrer');
  }

  customerImageUrl(image: CustomerImage): string {
    return this.debt.getCustomerImagePublicUrl(image.image_path);
  }

  isAvatarImage(image: CustomerImage): boolean {
    const avatarPath = this.imageManagerCustomer?.avatar_image_path?.trim();
    return !!avatarPath && avatarPath === image.image_path;
  }

  trackByCustomerImageId(_index: number, image: CustomerImage): string {
    return image.id;
  }

  trackByCustomerId(_index: number, customer: Customer): string {
    return customer.id;
  }

  statusLabel(customer: Customer): string {
    return customer.is_active === false ? 'Ngừng hoạt động' : 'Đang hoạt động';
  }

  formatCoordinate(value: number | null | undefined): string {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return '';
    }
    return value.toFixed(6);
  }

  focusCustomerOnOverviewMap(customer: CustomerView): void {
    const point = this.toCoordinatePoint(customer);
    if (!point) {
      return;
    }

    this.setActiveTab('map');

    void this.waitForDialogPaint().then(() => this.ensureOverviewMapReady()).then((ready) => {
      if (!ready || !this.overviewMapInstance) {
        return;
      }

      this.overviewMapInstance.panTo({ lat: point.lat, lng: point.lng });
      this.overviewMapInstance.setZoom(16);

      const marker = this.overviewMarkerByCustomerId.get(point.customer.id);
      if (marker) {
        this.openOverviewInfoWindow(marker, point);
      }

      this.overviewMapCanvas?.nativeElement.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    });
  }

  syncMapFromInputs(): void {
    let latitude: number | null = null;
    let longitude: number | null = null;

    try {
      latitude = this.parseCoordinate(this.customerForm.latitude, 'latitude');
      longitude = this.parseCoordinate(this.customerForm.longitude, 'longitude');
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Tọa độ không hợp lệ.';
      window.alert(message);
      return;
    }

    if (latitude === null || longitude === null) {
      window.alert('Vui lòng nhập đầy đủ vĩ độ và kinh độ để cập nhật bản đồ.');
      return;
    }

    const target = { lat: latitude, lng: longitude };

    if (!this.mapInstance || !this.mapMarker) {
      if (this.hasGoogleMapsApiKey) {
        void this.initializeGoogleMap().then(() => {
          if (!this.mapInstance || !this.mapMarker) return;
          this.mapMarker.setPosition(target);
          this.mapMarker.setDraggable?.(true);
          this.moveMapTo(target.lat, target.lng);
        });
      }
      return;
    }

    this.mapMarker.setPosition(target);
    this.mapMarker.setDraggable?.(true);
    this.moveMapTo(target.lat, target.lng);
  }

  syncInputsFromMap(): void {
    if (!this.mapInstance) {
      if (this.hasGoogleMapsApiKey) {
        void this.initializeGoogleMap().then(() => {
          if (!this.mapInstance) {
            window.alert('Bản đồ chưa sẵn sàng. Vui lòng thử lại.');
            return;
          }
          this.syncInputsFromMap();
        });
      } else {
        window.alert('Chưa cấu hình GOOGLE_MAPS_API_KEY để hiển thị bản đồ.');
      }
      return;
    }

    let latitude: number | null = null;
    let longitude: number | null = null;

    const markerPosition = this.mapMarker?.getPosition?.();
    if (
      markerPosition &&
      typeof markerPosition.lat === 'function' &&
      typeof markerPosition.lng === 'function'
    ) {
      latitude = markerPosition.lat();
      longitude = markerPosition.lng();
    } else {
      const mapCenter = this.mapInstance?.getCenter?.();
      if (
        mapCenter &&
        typeof mapCenter.lat === 'function' &&
        typeof mapCenter.lng === 'function'
      ) {
        latitude = mapCenter.lat();
        longitude = mapCenter.lng();
      }
    }

    if (latitude === null || longitude === null) {
      window.alert('Không lấy được vị trí từ bản đồ. Vui lòng thử lại.');
      return;
    }

    this.setCoordinatesFromMap(latitude, longitude);
  }

  async parseGoogleMapsLink(): Promise<void> {
    const rawLink = this.mapsLinkInput.trim();
    if (!rawLink) {
      window.alert('Vui lòng nhập link Google Maps.');
      return;
    }

    this.isResolvingMapLink = true;
    this.googleMapError = '';

    try {
      const resolvedLink = await this.resolveGoogleMapsLink(rawLink);
      const coordinates = await this.extractCoordinatesFromGoogleMapsLink(resolvedLink);

      if (!coordinates) {
        throw new Error('Không tìm thấy tọa độ trong link đã nhập.');
      }

      this.setCoordinatesFromMap(coordinates.lat, coordinates.lng);

      if (!this.mapInstance || !this.mapMarker) {
        if (this.hasGoogleMapsApiKey) {
          await this.initializeGoogleMap();
        } else {
          return;
        }
      }

      this.mapMarker.setPosition(coordinates);
      this.mapMarker.setDraggable?.(true);
      this.moveMapTo(coordinates.lat, coordinates.lng, 16);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Không thể phân tích link Google Maps.';
      this.googleMapError = message;
      window.alert(message);
    } finally {
      this.isResolvingMapLink = false;
    }
  }

  openGoogleMapsExternal(): void {
    const latitude = this.toCoordinateNumber(this.customerForm.latitude);
    const longitude = this.toCoordinateNumber(this.customerForm.longitude);
    const address = this.customerForm.address.trim();
    const query =
      latitude !== null && longitude !== null
        ? `${latitude},${longitude}`
        : address || `${this.defaultLatitude},${this.defaultLongitude}`;
    const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }

  private async refreshOverviewMap(): Promise<void> {
    if (this.activeTab !== 'map') {
      return;
    }

    const ready = await this.ensureOverviewMapReady();
    if (!ready) {
      return;
    }

    this.renderOverviewMarkers();
  }

  private async ensureOverviewMapReady(): Promise<boolean> {
    if (!this.hasGoogleMapsApiKey) {
      return false;
    }

    if (this.overviewMapInstance) {
      return true;
    }

    if (!this.overviewMapCanvas?.nativeElement) {
      return false;
    }

    this.overviewMapError = '';

    try {
      await this.loadGoogleMapsScript();
      return this.renderOverviewMap();
    } catch {
      this.overviewMapError = 'Không thể tải bản đồ tổng quát. Kiểm tra GOOGLE_MAPS_API_KEY và thử lại.';
      return false;
    }
  }

  private renderOverviewMap(): boolean {
    const googleMaps = window.google?.maps;
    const container = this.overviewMapCanvas?.nativeElement;
    if (!googleMaps || !container) {
      this.overviewMapError = 'Không thể khởi tạo bản đồ tổng quát.';
      return false;
    }

    this.overviewMapInstance = new googleMaps.Map(container, {
      center: { lat: this.defaultLatitude, lng: this.defaultLongitude },
      zoom: 12,
      streetViewControl: false,
      mapTypeControl: false,
      fullscreenControl: false
    });
    this.overviewMapInfoWindow = new googleMaps.InfoWindow();
    return true;
  }

  private renderOverviewMarkers(): void {
    const googleMaps = window.google?.maps;
    if (!googleMaps || !this.overviewMapInstance) {
      return;
    }

    this.clearOverviewMarkers();

    const points = this.filteredCustomers
      .map((customer) => this.toCoordinatePoint(customer))
      .filter((point): point is CustomerCoordinatePoint => point !== null);

    if (!points.length) {
      this.overviewMapInstance.setCenter({
        lat: this.defaultLatitude,
        lng: this.defaultLongitude
      });
      this.overviewMapInstance.setZoom(11);
      return;
    }

    const bounds = new googleMaps.LatLngBounds();

    for (const point of points) {
      const marker = new googleMaps.Marker({
        position: { lat: point.lat, lng: point.lng },
        map: this.overviewMapInstance,
        title: point.customer.name,
        icon: {
          path: googleMaps.SymbolPath.CIRCLE,
          scale: 8,
          fillColor: point.customer.is_active === false ? '#64748b' : '#2563eb',
          fillOpacity: 0.95,
          strokeColor: '#ffffff',
          strokeWeight: 2
        }
      });

      marker.addListener('click', () => this.openOverviewInfoWindow(marker, point));
      this.overviewMarkers.push(marker);
      this.overviewMarkerByCustomerId.set(point.customer.id, marker);
      bounds.extend({ lat: point.lat, lng: point.lng });
    }

    if (points.length === 1) {
      this.overviewMapInstance.setCenter({ lat: points[0].lat, lng: points[0].lng });
      this.overviewMapInstance.setZoom(16);
      return;
    }

    this.overviewMapInstance.fitBounds(bounds, 72);
  }

  private openOverviewInfoWindow(marker: any, point: CustomerCoordinatePoint): void {
    if (!this.overviewMapInfoWindow) {
      return;
    }

    const mapUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
      `${point.lat},${point.lng}`
    )}`;
    const phone = point.customer.phone
      ? `<div style="margin-top:4px;color:#475569;">${this.escapeHtml(point.customer.phone)}</div>`
      : '';
    const address = point.customer.address
      ? `<div style="margin-top:4px;color:#475569;">${this.escapeHtml(point.customer.address)}</div>`
      : '';

    this.overviewMapInfoWindow.setContent(`
      <div style="min-width:220px;max-width:260px;">
        <strong>${this.escapeHtml(point.customer.name)}</strong>
        ${phone}
        ${address}
        <div style="margin-top:6px;font-size:12px;color:#334155;">
          ${point.lat.toFixed(6)}, ${point.lng.toFixed(6)}
        </div>
        <a href="${mapUrl}" target="_blank" rel="noopener noreferrer" style="display:inline-block;margin-top:8px;"> Mở Google Maps </a>
      </div>
    `);
    this.overviewMapInfoWindow.open({
      map: this.overviewMapInstance,
      anchor: marker
    });
  }

  private clearOverviewMarkers(): void {
    this.overviewMapInfoWindow?.close?.();

    for (const marker of this.overviewMarkers) {
      marker.setMap?.(null);
    }

    this.overviewMarkers = [];
    this.overviewMarkerByCustomerId.clear();
  }

  private disposeOverviewMap(): void {
    this.setOverviewExpandedState(false);
    this.clearOverviewMarkers();
    this.overviewMapInfoWindow?.close?.();
    this.overviewMapInfoWindow = null;
    this.overviewMapInstance = null;
  }

  private setOverviewExpandedState(expanded: boolean): void {
    if (this.isOverviewMapExpanded === expanded) {
      return;
    }

    this.isOverviewMapExpanded = expanded;

    if (typeof document !== 'undefined') {
      document.body.style.overflow = expanded ? 'hidden' : '';
    }
  }

  private toCoordinatePoint(customer: CustomerView): CustomerCoordinatePoint | null {
    const lat = customer.latitude == null ? null : Number(customer.latitude);
    const lng = customer.longitude == null ? null : Number(customer.longitude);

    if (lat === null || lng === null || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      return null;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }

    return { customer, lat, lng };
  }

  private escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  private async initializeGoogleMap(): Promise<void> {
    if (!this.hasGoogleMapsApiKey) {
      return;
    }

    this.googleMapError = '';
    await this.waitForDialogPaint();

    try {
      await this.loadGoogleMapsScript();
      this.renderGoogleMap();
    } catch {
      this.googleMapError =
        'Không thể tải Google Map. Kiểm tra GOOGLE_MAPS_API_KEY và thử lại.';
    }
  }

  private waitForDialogPaint(): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  private async resolveGoogleMapsLink(rawLink: string): Promise<string> {
    const normalized = this.normalizeGoogleMapsLink(rawLink);

    if (!this.isGoogleShortLink(normalized)) {
      return normalized;
    }

    const endpoint = `https://unshorten.me/json/${encodeURIComponent(normalized)}`;
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        Accept: 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error('Không thể mở rộng link maps.app.goo.gl.');
    }

    const payload = (await response.json()) as UnshortenResponse;
    if (!payload.success || !payload.resolved_url) {
      throw new Error(payload.error || 'Không thể mở rộng link maps.app.goo.gl.');
    }

    return this.unwrapGoogleContinueUrl(payload.resolved_url);
  }

  private async extractCoordinatesFromGoogleMapsLink(
    link: string
  ): Promise<{ lat: number; lng: number } | null> {
    const fromPatterns = this.parseCoordinatesFromText(link, false);
    if (fromPatterns) {
      return fromPatterns;
    }

    let decoded = link;
    for (let i = 0; i < 2; i += 1) {
      try {
        decoded = decodeURIComponent(decoded);
      } catch {
        break;
      }

      const decodedCoordinates = this.parseCoordinatesFromText(decoded, false);
      if (decodedCoordinates) {
        return decodedCoordinates;
      }
    }

    try {
      const url = new URL(link);
      const queryCandidates = [
        url.searchParams.get('q'),
        url.searchParams.get('query'),
        url.searchParams.get('ll'),
        url.searchParams.get('center'),
        url.searchParams.get('destination')
      ];

      for (const value of queryCandidates) {
        if (!value) continue;

        const strictParsed = this.parseCoordinatesFromText(value, false);
        if (strictParsed) {
          return strictParsed;
        }

        const looseParsed = this.parseCoordinatesFromText(value, true);
        if (looseParsed) {
          return looseParsed;
        }

        const geocoded = await this.geocodeAddress(value);
        if (geocoded) {
          return geocoded;
        }
      }
    } catch {
      // Keep null and let caller show message.
    }

    return null;
  }

  private parseCoordinatesFromText(
    text: string,
    allowLooseLatLng: boolean
  ): { lat: number; lng: number } | null {
    const patterns: RegExp[] = [
      /@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
      /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/,
    ];

    if (allowLooseLatLng) {
      patterns.push(
        /(?:^|[^\d-])(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)(?!\d)/
      );
    }

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (!match) continue;

      const lat = Number(match[1]);
      const lng = Number(match[2]);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

      return { lat, lng };
    }

    return null;
  }

  private isGoogleShortLink(link: string): boolean {
    try {
      const url = new URL(link);
      return (
        url.hostname === 'maps.app.goo.gl' ||
        url.hostname === 'goo.gl' ||
        url.hostname === 'g.co'
      );
    } catch {
      return false;
    }
  }

  private normalizeGoogleMapsLink(rawLink: string): string {
    const trimmed = rawLink.trim();
    if (/^https?:\/\//i.test(trimmed)) {
      return trimmed;
    }
    return `https://${trimmed}`;
  }

  private unwrapGoogleContinueUrl(link: string): string {
    let current = link;

    for (let i = 0; i < 3; i += 1) {
      try {
        const url = new URL(current);
        const next = url.searchParams.get('continue');
        if (!next) {
          return current;
        }
        current = decodeURIComponent(next);
      } catch {
        return current;
      }
    }

    return current;
  }

  private geocodeAddress(address: string): Promise<{ lat: number; lng: number } | null> {
    const googleMaps = window.google?.maps;
    if (!googleMaps?.Geocoder) {
      return Promise.resolve(null);
    }

    const geocoder = new googleMaps.Geocoder();
    return new Promise((resolve) => {
      geocoder.geocode({ address }, (results: any, status: string) => {
        if (status !== 'OK' || !results?.length) {
          resolve(null);
          return;
        }

        const location = results[0]?.geometry?.location;
        const lat = location?.lat?.();
        const lng = location?.lng?.();
        if (typeof lat !== 'number' || typeof lng !== 'number') {
          resolve(null);
          return;
        }

        resolve({ lat, lng });
      });
    });
  }

  private loadGoogleMapsScript(): Promise<void> {
    if (window.google?.maps) {
      return Promise.resolve();
    }

    if (CustomersComponent.googleMapsScriptPromise) {
      return CustomersComponent.googleMapsScriptPromise;
    }

    const apiKey = APP_CONFIG.googleMapsApiKey?.trim();
    if (!apiKey) {
      return Promise.reject(new Error('Google Maps API key is missing.'));
    }

    CustomersComponent.googleMapsScriptPromise = new Promise<void>(
      (resolve, reject) => {
        const existing = document.getElementById('google-maps-js') as HTMLScriptElement | null;

        if (existing) {
          if (window.google?.maps) {
            resolve();
            return;
          }

          existing.addEventListener('load', () => resolve(), { once: true });
          existing.addEventListener(
            'error',
            () => reject(new Error('Google Maps script failed to load.')),
            { once: true }
          );
          return;
        }

        const script = document.createElement('script');
        script.id = 'google-maps-js';
        script.async = true;
        script.defer = true;
        script.src =
          `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}`;
        script.addEventListener('load', () => resolve(), { once: true });
        script.addEventListener(
          'error',
          () => reject(new Error('Google Maps script failed to load.')),
          { once: true }
        );
        document.head.appendChild(script);
      }
    ).catch((error) => {
      CustomersComponent.googleMapsScriptPromise = null;
      throw error;
    });

    return CustomersComponent.googleMapsScriptPromise;
  }

  private renderGoogleMap(): void {
    const googleMaps = window.google?.maps;
    const container = this.googleMapCanvas?.nativeElement;
    if (!googleMaps || !container) {
      this.googleMapError = 'Không thể khởi tạo Google Map.';
      return;
    }

    const initial = this.getInitialMapPosition();
    if (this.mapMarker?.setMap) {
      this.mapMarker.setMap(null);
    }

    this.mapInstance = new googleMaps.Map(container, {
      center: initial,
      zoom: 16,
      streetViewControl: false,
      mapTypeControl: false,
      fullscreenControl: false
    });

    this.rebuildMarker(initial.lat, initial.lng);

    this.mapInstance.addListener('click', (event: any) => {
      const lat = event?.latLng?.lat?.();
      const lng = event?.latLng?.lng?.();
      if (typeof lat !== 'number' || typeof lng !== 'number') {
        return;
      }
      this.setCoordinatesFromMap(lat, lng);
    });
  }

  private setCoordinatesFromMap(latitude: number, longitude: number): void {
    const next = {
      lat: Number(latitude.toFixed(6)),
      lng: Number(longitude.toFixed(6))
    };

    this.ngZone.run(() => {
      this.customerForm.latitude = next.lat.toFixed(6);
      this.customerForm.longitude = next.lng.toFixed(6);

      if (this.mapMarker) {
        this.mapMarker.setPosition(next);
        this.mapMarker.setDraggable?.(true);
      }
      this.moveMapTo(next.lat, next.lng);
    });
  }

  private rebuildMarker(latitude: number, longitude: number): void {
    const googleMaps = window.google?.maps;
    if (!googleMaps || !this.mapInstance) {
      return;
    }

    if (this.mapMarker?.setMap) {
      this.mapMarker.setMap(null);
    }

    this.mapMarker = new googleMaps.Marker({
      position: { lat: latitude, lng: longitude },
      map: this.mapInstance,
      draggable: true
    });
    this.mapMarker.setDraggable?.(true);
    this.mapMarker.addListener('dragend', (event: any) => {
      const lat = event?.latLng?.lat?.();
      const lng = event?.latLng?.lng?.();
      if (typeof lat !== 'number' || typeof lng !== 'number') {
        return;
      }
      this.setCoordinatesFromMap(lat, lng);
    });
  }

  private moveMapTo(latitude: number, longitude: number, zoom?: number): void {
    if (!this.mapInstance) {
      return;
    }

    if (typeof zoom === 'number') {
      this.mapInstance.setZoom(zoom);
    }
    this.mapInstance.panTo({ lat: latitude, lng: longitude });
  }

  private getInitialMapPosition(): { lat: number; lng: number } {
    const latitude = this.toCoordinateNumber(this.customerForm.latitude);
    const longitude = this.toCoordinateNumber(this.customerForm.longitude);
    if (latitude !== null && longitude !== null) {
      return { lat: latitude, lng: longitude };
    }
    return { lat: this.defaultLatitude, lng: this.defaultLongitude };
  }

  private toCoordinateNumber(value: string): number | null {
    const normalized = value.trim().replace(',', '.');
    if (!normalized) {
      return null;
    }
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }

  private createEmptyForm(): CustomerFormModel {
    return {
      name: '',
      phone: '',
      address: '',
      latitude: this.defaultLatitude.toFixed(6),
      longitude: this.defaultLongitude.toFixed(6),
      is_active: true
    };
  }

  private toFormModel(customer: Customer): CustomerFormModel {
    return {
      name: customer.name,
      phone: customer.phone ?? '',
      address: customer.address ?? '',
      latitude: customer.latitude != null ? String(customer.latitude) : '',
      longitude: customer.longitude != null ? String(customer.longitude) : '',
      is_active: customer.is_active ?? true
    };
  }

  private parseCoordinate(
    value: string,
    axis: 'latitude' | 'longitude'
  ): number | null {
    const normalized = value.trim().replace(',', '.');
    if (!normalized) {
      return null;
    }

    const parsed = Number(normalized);
    if (!Number.isFinite(parsed)) {
      throw new Error(axis === 'latitude' ? 'Vĩ độ không hợp lệ.' : 'Kinh độ không hợp lệ.');
    }

    if (axis === 'latitude' && (parsed < -90 || parsed > 90)) {
      throw new Error('Vĩ độ phải nằm trong khoảng từ -90 đến 90.');
    }

    if (axis === 'longitude' && (parsed < -180 || parsed > 180)) {
      throw new Error('Kinh độ phải nằm trong khoảng từ -180 đến 180.');
    }

    return parsed;
  }

  private patchCustomerAvatar(customerId: string, avatarImagePath: string | null): void {
    const avatarUrl = avatarImagePath
      ? this.debt.getCustomerImagePublicUrl(avatarImagePath)
      : null;

    this.customers = this.customers.map((customer) =>
      customer.id === customerId
        ? { ...customer, avatar_image_path: avatarImagePath, avatarUrl }
        : customer
    );

    if (this.imageManagerCustomer?.id === customerId) {
      this.imageManagerCustomer = {
        ...this.imageManagerCustomer,
        avatar_image_path: avatarImagePath,
        avatarUrl
      };
    }
  }

  private resolveErrorMessage(error: unknown, fallback: string): string {
    if (error instanceof Error && error.message.trim()) {
      return error.message;
    }

    if (typeof error === 'object' && error !== null) {
      const maybeMessage = (error as { message?: unknown }).message;
      if (typeof maybeMessage === 'string' && maybeMessage.trim()) {
        return maybeMessage;
      }
    }

    return fallback;
  }

  private toCustomerView(customer: Customer): CustomerView {
    const imagePath = customer.avatar_image_path?.trim();
    const avatarUrl = imagePath
      ? this.debt.getCustomerImagePublicUrl(imagePath)
      : null;

    return { ...customer, avatarUrl };
  }
}
