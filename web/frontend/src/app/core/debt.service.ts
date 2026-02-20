import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import {
  Customer,
  CustomerImage,
  CustomerSale,
  DebtLine,
  DebtPayment
} from '../models/customer.model';
import { supabase } from './supabase.client';

@Injectable({
  providedIn: 'root'
})
export class DebtService {
  private readonly customerImagesTable = 'customer_images';
  private readonly customerImagesBucket = 'customer-images';
  private readonly maxCustomerImages = 20;
  private readonly customerImageMaxWidth = 1920;
  private readonly customerImageJpegQuality = 0.82;

  getCustomers(onlyDebt = false, includeInactive = false): Observable<Customer[]> {
    let query = supabase.from('customers').select('*').order('created_at', { ascending: false });

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    if (onlyDebt) {
      query = query.gt('current_debt', 0);
    }

    return from(query).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }

  createCustomer(payload: Partial<Customer>): Observable<Customer> {
    return from(
      supabase.from('customers').insert(payload).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return data as Customer;
      })
    );
  }

  updateCustomer(id: string, payload: Partial<Customer>): Observable<Customer> {
    return from(
      supabase.from('customers').update(payload).eq('id', id).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Update failed');
        return data as Customer;
      })
    );
  }

  deleteCustomer(id: string): Observable<{ id: string }> {
    return from(
      supabase.from('customers').update({ is_active: false }).eq('id', id).select('id').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Delete failed');
        return { id: data.id };
      })
    );
  }

  getCustomerImages(customerId: string, activeOnly = true): Observable<CustomerImage[]> {
    let query = supabase
      .from(this.customerImagesTable)
      .select('*')
      .eq('customer_id', customerId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    return from(query.order('created_at', { ascending: false })).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? []) as CustomerImage[];
      })
    );
  }

  uploadCustomerImage(
    customerId: string,
    file: File,
    note?: string | null
  ): Observable<CustomerImage> {
    return from(this.uploadCustomerImageInternal(customerId, file, note));
  }

  setCustomerAvatar(customerId: string, imagePath: string | null): Observable<void> {
    return from(this.setCustomerAvatarInternal(customerId, imagePath));
  }

  deleteCustomerImage(imageId: string): Observable<void> {
    return from(this.deleteCustomerImageInternal(imageId));
  }

  getCustomerImagePublicUrl(imagePath: string): string {
    return supabase.storage
      .from(this.customerImagesBucket)
      .getPublicUrl(imagePath)
      .data.publicUrl;
  }

  getCustomerHistory(
    id: string,
    limit = 20,
    year?: number | null
  ): Observable<{ sales: CustomerSale[]; payments: DebtPayment[] }> {
    const range = this.getYearRange(year);
    return from(
      Promise.all([
        (() => {
          let query = supabase
            .from('sales')
            .select(
              'id, invoice_number, total_amount, discount_amount, final_amount, payment_method, payment_status, created_at, due_date'
            )
            .eq('customer_id', id)
            .order('created_at', { ascending: false })
            .limit(limit);
          if (range) {
            query = query.gte('created_at', range.start).lt('created_at', range.end);
          }
          return query;
        })(),
        (() => {
          let query = supabase
            .from('debt_payments')
            .select('id, amount, payment_method, notes, created_at')
            .eq('customer_id', id)
            .order('created_at', { ascending: false })
            .limit(limit);
          if (range) {
            query = query.gte('created_at', range.start).lt('created_at', range.end);
          }
          return query;
        })()
      ])
    ).pipe(
      map(([salesRes, paymentsRes]) => {
        if (salesRes.error) throw salesRes.error;
        if (paymentsRes.error) throw paymentsRes.error;
        return {
          sales: (salesRes.data ?? []) as CustomerSale[],
          payments: (paymentsRes.data ?? []) as DebtPayment[]
        };
      })
    );
  }

  getDebtLines(
    id: string,
    year?: number | null,
    duplicateOnly = false
  ): Observable<DebtLine[]> {
    const range = this.getYearRange(year);
    if (duplicateOnly) {
      return from(
        supabase.rpc('get_duplicate_debt_lines', {
          p_customer_id: id,
          p_year: year ?? null
        })
      ).pipe(
        map(({ data, error }) => {
          if (error) throw error;
          return (data ?? []).map((line: any) => ({
            id: line.id,
            invoice_number: line.invoice_number ?? '',
            created_at: line.created_at,
            due_date: line.due_date,
            final_amount: line.final_amount ?? 0,
            notes: line.notes ?? null,
            items: Array.isArray(line.items)
              ? line.items.map((item: any) => ({
                  quantity: item.quantity,
                  unit_price: item.unit_price,
                  subtotal: item.subtotal,
                  product_name: item.product_name ?? '',
                  unit: item.unit ?? ''
                }))
              : []
          })) as DebtLine[];
        })
      );
    }

    return from(
      (() => {
        let query = supabase
          .from('sales')
          .select(
            'id, invoice_number, created_at, due_date, final_amount, notes, payment_method, sale_items(quantity, unit_price, subtotal, product:products(name, unit))'
          )
          .eq('customer_id', id)
          .eq('payment_method', 'debt')
          .order('created_at', { ascending: false });
        if (range) {
          query = query.gte('created_at', range.start).lt('created_at', range.end);
        }
        return query;
      })()
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? []).map((sale: any) => ({
          id: sale.id,
          invoice_number: sale.invoice_number,
          created_at: sale.created_at,
          due_date: sale.due_date,
          final_amount: sale.final_amount,
          notes: sale.notes,
          items: Array.isArray(sale.sale_items)
            ? sale.sale_items.map((item: any) => ({
                quantity: item.quantity,
                unit_price: item.unit_price,
                subtotal: item.subtotal,
                product_name: item.product?.name ?? '',
                unit: item.product?.unit ?? ''
              }))
            : []
        })) as DebtLine[];
      })
    );
  }

  createDebtLine(
    customerId: string,
    payload: {
      amount: number;
      purchase_date?: string | null;
      due_date?: string | null;
      notes?: string | null;
    }
  ): Observable<DebtLine> {
    return from(
      supabase
        .from('sales')
        .insert({
          customer_id: customerId,
          total_amount: payload.amount,
          discount_amount: 0,
          final_amount: payload.amount,
          payment_method: 'debt',
          payment_status: 'unpaid',
          due_date: payload.due_date ?? null,
          notes: payload.notes ?? null,
          created_at: payload.purchase_date ?? undefined
        })
        .select('*')
        .single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return data as DebtLine;
      })
    );
  }

  updateDebtLine(
    id: string,
    payload: {
      amount?: number;
      purchase_date?: string | null;
      due_date?: string | null;
      notes?: string | null;
    }
  ): Observable<DebtLine> {
    return from(
      supabase.rpc('update_debt_line', {
        p_sale_id: id,
        p_amount: payload.amount ?? null,
        p_purchase_date: payload.purchase_date ?? null,
        p_due_date: payload.due_date ?? null,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Update failed');
        return data as DebtLine;
      })
    );
  }

  deleteDebtLine(id: string): Observable<{ id: string }> {
    return from(
      supabase.rpc('delete_debt_line', { p_sale_id: id })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? { id }) as { id: string };
      })
    );
  }

  recordPayment(payload: {
    customer_id: string;
    amount: number;
    payment_method: 'cash' | 'transfer';
    notes?: string | null;
  }): Observable<unknown> {
    return from(
      supabase.from('debt_payments').insert(payload).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? {};
      })
    );
  }

  updatePayment(
    id: string,
    payload: {
      amount?: number;
      payment_method?: 'cash' | 'transfer';
      notes?: string | null;
    }
  ): Observable<unknown> {
    return from(
      supabase.rpc('update_debt_payment', {
        p_payment_id: id,
        p_amount: payload.amount ?? null,
        p_payment_method: payload.payment_method ?? null,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? {};
      })
    );
  }

  deletePayment(id: string): Observable<{ id: string }> {
    return from(
      supabase.rpc('delete_debt_payment', { p_payment_id: id })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? { id }) as { id: string };
      })
    );
  }

  private getYearRange(
    year?: number | null
  ): { start: string; end: string } | null {
    if (!year || !Number.isFinite(year)) return null;
    const start = new Date(Date.UTC(year, 0, 1)).toISOString();
    const end = new Date(Date.UTC(year + 1, 0, 1)).toISOString();
    return { start, end };
  }

  private sanitizeFileName(fileName: string): string {
    const sanitized = fileName.trim().replace(/[^a-zA-Z0-9._-]/g, '_');
    return sanitized || 'image.jpg';
  }

  private fileNameWithoutExtension(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.slice(0, dotIndex);
  }

  private buildCompressedFileName(fileName: string): string {
    const baseName = this.fileNameWithoutExtension(fileName).trim() || 'image';
    return `${baseName}_compressed.jpg`;
  }

  private buildCustomerImagePath(customerId: string, fileName: string): string {
    return `${customerId}/${Date.now()}-${this.sanitizeFileName(fileName)}`;
  }

  private async ensureCustomerImageLimit(customerId: string): Promise<void> {
    const { data, error } = await supabase
      .from(this.customerImagesTable)
      .select('id')
      .eq('customer_id', customerId)
      .eq('is_active', true);

    if (error) {
      throw error;
    }

    if ((data ?? []).length >= this.maxCustomerImages) {
      throw new Error(`Khách hàng đã đạt giới hạn ${this.maxCustomerImages} ảnh.`);
    }
  }

  private async uploadCustomerImageInternal(
    customerId: string,
    file: File,
    note?: string | null
  ): Promise<CustomerImage> {
    await this.ensureCustomerImageLimit(customerId);

    const preparedFile = await this.compressImageForUpload(file);
    const normalizedName = this.sanitizeFileName(preparedFile.name || file.name || 'image.jpg');
    const imagePath = this.buildCustomerImagePath(customerId, normalizedName);
    const contentType = preparedFile.type?.trim() || 'image/jpeg';
    let uploaded = false;

    try {
      const { error: uploadError } = await supabase.storage
        .from(this.customerImagesBucket)
        .upload(imagePath, preparedFile, {
          contentType,
          upsert: false
        });

      if (uploadError) {
        throw uploadError;
      }
      uploaded = true;

      const { data, error } = await supabase
        .from(this.customerImagesTable)
        .insert({
          customer_id: customerId,
          image_path: imagePath,
          note: note?.trim() || null
        })
        .select('*')
        .single();

      if (error || !data) {
        throw error ?? new Error('Upload failed');
      }

      return data as CustomerImage;
    } catch (error) {
      if (uploaded) {
        const { error: removeError } = await supabase.storage
          .from(this.customerImagesBucket)
          .remove([imagePath]);
        if (removeError) {
          throw removeError;
        }
      }
      throw error;
    }
  }

  private async compressImageForUpload(file: File): Promise<File> {
    if (!file.type.startsWith('image/')) {
      return file;
    }

    if (file.type === 'image/svg+xml') {
      return file;
    }

    if (typeof document === 'undefined' || typeof createImageBitmap !== 'function') {
      return file;
    }

    let bitmap: ImageBitmap | null = null;
    try {
      bitmap = await this.decodeImageBitmap(file);
      const sourceWidth = bitmap.width;
      const sourceHeight = bitmap.height;

      if (sourceWidth <= 0 || sourceHeight <= 0) {
        return file;
      }

      const scale =
        sourceWidth > this.customerImageMaxWidth
          ? this.customerImageMaxWidth / sourceWidth
          : 1;

      const targetWidth = Math.max(1, Math.round(sourceWidth * scale));
      const targetHeight = Math.max(1, Math.round(sourceHeight * scale));
      const canvas = document.createElement('canvas');
      canvas.width = targetWidth;
      canvas.height = targetHeight;

      const context = canvas.getContext('2d', { alpha: false });
      if (!context) {
        return file;
      }

      context.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
      const compressedBlob = await this.canvasToJpegBlob(
        canvas,
        this.customerImageJpegQuality
      );

      if (!compressedBlob) {
        return file;
      }

      const compressedName = this.buildCompressedFileName(file.name || 'image.jpg');
      return new File([compressedBlob], compressedName, { type: 'image/jpeg' });
    } catch {
      return file;
    } finally {
      bitmap?.close();
    }
  }

  private async decodeImageBitmap(file: File): Promise<ImageBitmap> {
    try {
      return await createImageBitmap(
        file,
        { imageOrientation: 'from-image' } as ImageBitmapOptions
      );
    } catch {
      return createImageBitmap(file);
    }
  }

  private canvasToJpegBlob(
    canvas: HTMLCanvasElement,
    quality: number
  ): Promise<Blob | null> {
    return new Promise((resolve) => {
      canvas.toBlob((blob) => resolve(blob), 'image/jpeg', quality);
    });
  }

  private async setCustomerAvatarInternal(
    customerId: string,
    imagePath: string | null
  ): Promise<void> {
    const normalizedPath = imagePath?.trim() || null;

    if (normalizedPath) {
      const { data, error } = await supabase
        .from(this.customerImagesTable)
        .select('id')
        .eq('customer_id', customerId)
        .eq('image_path', normalizedPath)
        .eq('is_active', true)
        .maybeSingle();

      if (error) {
        throw error;
      }

      if (!data) {
        throw new Error('Ảnh không thuộc khách hàng này.');
      }
    }

    const { error } = await supabase
      .from('customers')
      .update({ avatar_image_path: normalizedPath })
      .eq('id', customerId);

    if (error) {
      throw error;
    }
  }

  private async deleteCustomerImageInternal(imageId: string): Promise<void> {
    const { data, error } = await supabase
      .from(this.customerImagesTable)
      .select('id, image_path, customer_id')
      .eq('id', imageId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return;
    }

    const imagePath = typeof data.image_path === 'string' ? data.image_path : '';
    const customerId = typeof data.customer_id === 'string' ? data.customer_id : '';

    if (imagePath) {
      if (customerId) {
        const { error: clearAvatarError } = await supabase
          .from('customers')
          .update({ avatar_image_path: null })
          .eq('id', customerId)
          .eq('avatar_image_path', imagePath);

        if (clearAvatarError) {
          throw clearAvatarError;
        }
      }

      const { error: removeError } = await supabase.storage
        .from(this.customerImagesBucket)
        .remove([imagePath]);

      if (removeError) {
        throw removeError;
      }
    }

    const { error: deleteError } = await supabase
      .from(this.customerImagesTable)
      .delete()
      .eq('id', imageId);

    if (deleteError) {
      throw deleteError;
    }
  }
}
