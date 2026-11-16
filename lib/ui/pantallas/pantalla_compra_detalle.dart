import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../datos/modelos/compra.dart';
import '../../datos/modelos/compra_detalle.dart';
import '../../estado/compras_providers.dart';
import '../widgets/aviso.dart';
import '../widgets/chip_estado_compra.dart';
import '../widgets/imagen_remota.dart';
import '../widgets/seguimiento_compra.dart';
import 'pantalla_producto.dart';

/// Detalle de una compra: `GET /api/v1/compras/{id}`.
///
/// Equivale a `compras/show.blade.php`, reordenado para una pantalla angosta:
/// en la web el seguimiento y el detalle van en una columna y el resumen en
/// otra; acá van uno abajo del otro, con el seguimiento primero porque es lo
/// que el cliente viene a mirar.
///
/// **Los importes son los del documento, no los del catálogo de hoy.** Vienen
/// congelados de `venta_lineas` y `ventas`. Si el producto cambió de precio
/// después, esta pantalla sigue mostrando lo que se cobró.
///
/// Agrega dos bloques que la vista web no tiene: los pagos —la vista carga la
/// relación y no la usa— y las notas de crédito de una devolución.
class PantallaCompraDetalle extends ConsumerWidget {
  const PantallaCompraDetalle({
    super.key,
    required this.compraId,
    this.numeroConocido,
  });

  final int compraId;

  /// El número formateado que ya traía el historial, para titular la pantalla
  /// mientras carga. Null si se entró sin pasar por la lista.
  final String? numeroConocido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(detalleCompraProvider(compraId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          // El número que llegó manda; el conocido es el relleno del medio
          // segundo que tarda, para no mostrar un encabezado vacío.
          detalle.value?.numeroFormateado ?? numeroConocido ?? 'Pedido',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
            color: Color(0xFF202B3C),
          ),
        ),
      ),
      body: SafeArea(
        child: detalle.when(
          loading: () => const Center(child: CircularProgressIndicator()),

          error: (e, _) => _Falla(
            error: e,
            onReintentar: () =>
                ref.invalidate(detalleCompraProvider(compraId)),
          ),

          data: (compra) => RefreshIndicator(
            onRefresh: () => ref.refresh(detalleCompraProvider(compraId).future),
            child: _Cuerpo(compra: compra),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Error
// ====================================================================

/// **El 404 se trata aparte.** El backend responde lo mismo para un pedido de
/// otro cliente, uno que no existe y un presupuesto —un 403 confirmaría que
/// ese número existe—, así que el mensaje no afirma cuál de los tres es. Lo
/// que sí hace es no ofrecer "Reintentar": insistir sobre un 404 no lo va a
/// convertir en otra cosa, y el botón invita a quedarse trabado.
class _Falla extends StatelessWidget {
  const _Falla({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (error is ErrorNoEncontrado) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              const Text(
                'No encontramos este pedido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puede que ya no esté disponible en tu historial. Volvé a '
                'tus compras y abrilo desde la lista.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Volver',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        AvisoError(
          // `detalle.when` entrega el error como Object. Si no fuera un
          // ErrorApi, no vino del repositorio: se envuelve para poder
          // mostrarlo con el mismo cartel en lugar de dejar la pantalla en
          // blanco.
          error: error is ErrorApi
              ? error as ErrorApi
              : ErrorFormato('Error inesperado: $error'),
          onReintentar: onReintentar,
        ),
      ],
    );
  }
}

// ====================================================================
// Cuerpo
// ====================================================================

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.compra});

  final CompraDetalle compra;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        _Encabezado(compra: compra),

        const SizedBox(height: 20),

        // Seguimiento o desenlace: nunca los dos. Lo decide `enCurso`.
        _Tarjeta(
          titulo: compra.enCurso ? 'Seguimiento' : 'Estado del pedido',
          child: _seguimientoODesenlace(compra),
        ),

        const SizedBox(height: 16),

        _Tarjeta(
          titulo: 'Detalle',
          child: Column(
            children: [
              for (var i = 0; i < compra.lineas.length; i++)
                _FilaLinea(
                  linea: compra.lineas[i],
                  esUltima: i == compra.lineas.length - 1,
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _Tarjeta(
          titulo: 'Resumen',
          child: _Importes(importes: compra.importes),
        ),

        const SizedBox(height: 16),

        _Tarjeta(
          titulo: 'Entrega',
          child: _Entrega(
            entrega: compra.entrega,
            observaciones: compra.observaciones,
          ),
        ),

        const SizedBox(height: 16),

        _Tarjeta(
          titulo: 'Pago',
          child: _Pagos(resumen: compra.pago, pagos: compra.pagos),
        ),

        const SizedBox(height: 16),

        _Tarjeta(
          titulo: 'Facturación',
          child: _Facturacion(facturacion: compra.facturacion),
        ),
      ],
    );
  }

  Widget _seguimientoODesenlace(CompraDetalle compra) {
    final desenlace = compra.desenlace;

    if (desenlace != null) {
      return AvisoDesenlace(desenlace: desenlace);
    }

    if (compra.seguimiento.isEmpty) {
      // No debería pasar: un pedido en curso siempre trae pasos. Si pasara,
      // el estado del encabezado ya dice lo esencial y la tarjeta no queda
      // vacía sin explicación.
      return const Text(
        'No hay información de seguimiento para este pedido.',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      );
    }

    return SeguimientoCompra(pasos: compra.seguimiento);
  }
}

/// Número, fecha, canal y chip de estado.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.compra});

  final CompraDetalle compra;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PEDIDO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            compra.numeroFormateado,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: Color(0xFF202B3C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compra.esDelMostrador
                ? '${Formato.fecha(compra.fecha)} · ${compra.canal.etiqueta}'
                : Formato.fecha(compra.fecha),
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ChipEstadoCompra(estado: compra.estado),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Líneas
// ====================================================================

class _FilaLinea extends StatelessWidget {
  const _FilaLinea({required this.linea, required this.esUltima});

  final LineaCompra linea;
  final bool esUltima;

  @override
  Widget build(BuildContext context) {
    final productoId = linea.productoId;

    // Se abre la ficha sólo si el backend dijo que se puede: un producto
    // despublicado sigue en el pedido —se lo vendieron— pero su ficha
    // responde 404.
    final puedeAbrir = linea.productoEnlazable && productoId != null;

    final contenido = Padding(
      padding: EdgeInsets.symmetric(vertical: esUltima ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EDF3)),
              ),
              child: ImagenRemota(
                url: linea.imagenUrl,
                relleno: const EdgeInsets.all(5),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // La descripción congelada de la línea, no el nombre actual
                  // del producto.
                  linea.descripcion,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: puedeAbrir
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${linea.cantidad} × ${Formato.pesos(linea.precioUnitario)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (linea.tieneDescuento) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Descuento: −${Formato.pesos(linea.descuentoPromocion)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ColoresTono.verde,
                    ),
                  ),
                ],
                if (linea.fueDevuelta) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${linea.cantidadDevuelta} '
                      '${linea.cantidadDevuelta == 1 ? 'unidad devuelta' : 'unidades devueltas'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            Formato.pesos(linea.total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF202B3C),
            ),
          ),
        ],
      ),
    );

    final fila = puedeAbrir
        ? InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PantallaProducto(
                  productoId: productoId,
                  nombre: linea.descripcion,
                ),
              ),
            ),
            child: contenido,
          )
        : contenido;

    if (esUltima) return fila;

    return Column(
      children: [
        fila,
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}

// ====================================================================
// Importes
// ====================================================================

class _Importes extends StatelessWidget {
  const _Importes({required this.importes});

  final ImportesCompra importes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilaImporte(
          etiqueta: 'Subtotal',
          valor: Formato.pesos(importes.subtotal),
        ),

        // Las filas de descuento y envío sólo aparecen cuando aplican, igual
        // que en la vista: una línea en cero no informa nada.
        if (importes.hayDescuento)
          _FilaImporte(
            etiqueta: 'Descuentos',
            valor: '−${Formato.pesos(importes.descuentoPromociones)}',
            color: ColoresTono.verde,
            destacado: true,
          ),

        if (importes.hayEnvio)
          _FilaImporte(
            etiqueta: 'Envío',
            valor: Formato.pesos(importes.costoEnvio),
          ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: Color(0xFFE8EDF3)),
        ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202B3C),
                ),
              ),
            ),
            Text(
              Formato.pesos(importes.total),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Color(0xFF202B3C),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'IVA incluido: ${Formato.pesos(importes.totalIva)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}

class _FilaImporte extends StatelessWidget {
  const _FilaImporte({
    required this.etiqueta,
    required this.valor,
    this.color,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final Color? color;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 13,
      fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
      color: color ?? const Color(0xFF64748B),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(
            valor,
            style: estilo.copyWith(
              color: color ?? const Color(0xFF202B3C),
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Entrega
// ====================================================================

class _Entrega extends StatelessWidget {
  const _Entrega({required this.entrega, this.observaciones});

  final EntregaCompra entrega;
  final String? observaciones;

  @override
  Widget build(BuildContext context) {
    final envio = entrega.envio;
    final notas = observaciones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              entrega.esRetiro
                  ? Icons.storefront_rounded
                  : Icons.local_shipping_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entrega.modo.etiqueta,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202B3C),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // El texto lo escribe el backend: depende del modo de entrega y del
        // número de pedido.
        Text(
          entrega.instrucciones,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: Color(0xFF64748B),
          ),
        ),

        if (envio != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          _Dato(
            etiqueta: 'Dirección',
            valor: envio.direccionCompleta,
            icono: Icons.location_on_outlined,
          ),
          if (envio.estado != null)
            _Dato(
              etiqueta: 'Estado del envío',
              valor: envio.estado!,
              icono: Icons.inventory_2_outlined,
            ),
          if (envio.fechaDespacho != null)
            _Dato(
              etiqueta: 'Despachado',
              valor: Formato.fecha(envio.fechaDespacho),
              icono: Icons.event_available_outlined,
            ),
          if (envio.tieneSeguimiento)
            _Dato(
              etiqueta: 'Seguimiento',
              valor: envio.trackingUrl!,
              icono: Icons.link_rounded,
            ),
        ],

        if (notas != null && notas.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          const Text(
            'Observaciones',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notas,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF202B3C),
            ),
          ),
        ],
      ],
    );
  }
}

// ====================================================================
// Pagos
// ====================================================================

class _Pagos extends StatelessWidget {
  const _Pagos({required this.resumen, required this.pagos});

  final ResumenPago resumen;
  final List<PagoCompra> pagos;

  @override
  Widget build(BuildContext context) {
    final color = resumen.estaPagado ? ColoresTono.verde : ColoresTono.ambar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              resumen.estaPagado
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resumen.etiqueta,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),

        // El saldo sólo se muestra si falta cobrar algo: en un pedido pagado
        // sería una línea en cero.
        if (!resumen.estaPagado && resumen.saldo > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Saldo pendiente: ${Formato.pesos(resumen.saldo)}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],

        if (pagos.isEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Todavía no registramos ningún pago de este pedido.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
        ] else ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          for (final pago in pagos) _FilaPago(pago: pago),
        ],
      ],
    );
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({required this.pago});

  final PagoCompra pago;

  @override
  Widget build(BuildContext context) {
    final color = switch (pago.estado.valor) {
      'acreditado' => ColoresTono.verde,
      'rechazado' => ColoresTono.rojo,
      'devuelto' => ColoresTono.gris,
      _ => ColoresTono.ambar,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pago.metodo.etiqueta,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    // Las cuotas sólo vienen en tarjeta.
                    if (pago.cuotas != null && pago.cuotas! > 1)
                      Text(
                        ' · ${pago.cuotas} cuotas',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  Formato.fechaHora(pago.fecha),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formato.pesos(pago.monto),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                pago.estado.etiqueta,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Facturación
// ====================================================================

class _Facturacion extends StatelessWidget {
  const _Facturacion({required this.facturacion});

  final FacturacionCompra facturacion;

  @override
  Widget build(BuildContext context) {
    final factura = facturacion.factura;

    if (factura == null) {
      // Sin factura autorizada. Puede ser que el pago todavía no se acreditó,
      // o que ARCA la rechazó: un rechazo no invalida la compra y se resuelve
      // desde gestión. En los dos casos el cliente no tiene nada que hacer,
      // así que el mensaje no distingue.
      return const Text(
        'La factura de este pedido todavía no está disponible. Si ya '
        'pagaste, la vas a ver acá en breve.',
        style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF64748B)),
      );
    }

    final notas = facturacion.notasCredito;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Comprobante(comprobante: factura),

        if (notas.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          const Text(
            'Notas de crédito',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: Color(0xFF64748B),
            ),
          ),
          for (final nota in notas) ...[
            const SizedBox(height: 10),
            _Comprobante(comprobante: nota),
          ],
        ],
      ],
    );
  }
}

class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.comprobante});

  final ComprobanteCompra comprobante;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Dato(
          etiqueta: 'Comprobante',
          valor: comprobante.tipo,
          icono: comprobante.esNotaCredito
              ? Icons.receipt_outlined
              : Icons.receipt_long_outlined,
        ),
        _Dato(
          etiqueta: 'Número',
          valor: comprobante.numeroFormateado,
          icono: Icons.numbers_rounded,
        ),
        _Dato(
          etiqueta: 'Fecha',
          valor: Formato.fecha(comprobante.fechaEmision),
          icono: Icons.event_outlined,
        ),
        _Dato(
          etiqueta: 'Importe',
          valor: Formato.pesos(comprobante.total),
          icono: Icons.payments_outlined,
        ),

        // `autorizado` ya exige CAE no nulo: si está autorizado, hay CAE.
        if (comprobante.autorizado && comprobante.cae != null)
          _Dato(
            etiqueta: 'CAE',
            valor: comprobante.caeVencimiento == null
                ? comprobante.cae!
                : '${comprobante.cae} · vence el '
                    '${Formato.fecha(comprobante.caeVencimiento)}',
            icono: Icons.verified_outlined,
          )
        else
          _Dato(
            etiqueta: 'Estado',
            valor: comprobante.estado.etiqueta,
            icono: Icons.pending_outlined,
          ),
      ],
    );
  }
}

// ====================================================================
// Piezas compartidas
// ====================================================================

/// Tarjeta blanca con título, como las de "Mi cuenta".
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Fila etiqueta/valor con ícono. Mismo formato que `_Dato` de "Mi cuenta",
/// más compacto porque acá hay más filas por tarjeta.
class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.icono,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icono, size: 16, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: Color(0xFF202B3C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
