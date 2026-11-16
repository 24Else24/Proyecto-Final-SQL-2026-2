/* =====================================================================
   Desarrollo de Bases de Datos 2026-2
   TALLER 20 %: Clínica veterinaria VetAmigos
   FASE 3: Modelo físico en T-SQL y datos.
   Variante: A Agenda     D = 1     Cédulas: <1011512001> (menor) y <cédula2>
   SQL Server / SSMS.

   Códigos de los CHAR(1) que usa el modelo:
      Cita.estado       P programada, A atendida, C cancelada, N no asistió
      Factura.estado    P pendiente, C cancelada (pagada completa), A anulada
      Producto.tipo     S servicio, M medicamento, V vacuna, A accesorio
      Mascota.sexo      M macho, H hembra
   ===================================================================== */


-- =====================================================================
-- PASO 0.
-- =====================================================================
CREATE DATABASE VetAmigos;
GO
USE VetAmigos;
GO


-- =====================================================================
-- TABLAS
-- Acciones referenciales (resumen). Todas las FK son NO ACTION (no se
-- borra el padre mientras tenga hijos) EXCEPTO ClienteTelefono:
--   * cliente    -> no se borra un cliente con mascotas ("no se borra un
--                   cliente que tenga mascotas registradas").
--   * atención   -> el historial clínico no se borra; además sus líneas ya
--                   descontaron stock: borrarlas descuadraría el inventario.
--   * producto   -> se descontinúa (descontinuado = 1), no se borra.
--   * factura    -> se anula (estado 'A'), no se borra.
-- =====================================================================

CREATE TABLE Cliente (
    documento     VARCHAR(15)  NOT NULL,
    nombres       VARCHAR(60)  NOT NULL,
    apellidos     VARCHAR(60)  NOT NULL,
    correo        VARCHAR(100) NULL,         -- opcional ("cuando lo tienen")
    calle         VARCHAR(100) NOT NULL,     -- dirección: calle + ciudad
    ciudad        VARCHAR(30)  NOT NULL,
    fecha_cliente DATE         NOT NULL CONSTRAINT DF_Cliente_fecha_cliente DEFAULT (CAST(SYSDATETIME() AS DATE)),
    CONSTRAINT PK_Cliente PRIMARY KEY (documento),
    CONSTRAINT CK_Cliente_correo CHECK (correo LIKE '%_@_%._%')       -- NULL pasa el CHECK
);
-- UNIQUE normal solo admite UN NULL; el correo es opcional pero único cuando
-- existe, por eso es un índice único filtrado.
CREATE UNIQUE INDEX UQ_Cliente_correo ON Cliente (correo) WHERE correo IS NOT NULL;
GO

-- Teléfono: atributo multivaluado de Cliente -> tabla aparte.
-- CASCADE (la única): un teléfono no existe sin su cliente. Solo se borra
-- un cliente sin mascotas (FK_Mascota_Cliente lo impide en los demás casos).
CREATE TABLE ClienteTelefono (
    documento VARCHAR(15) NOT NULL,
    telefono  VARCHAR(15) NOT NULL,
    CONSTRAINT PK_ClienteTelefono PRIMARY KEY (documento, telefono),
    CONSTRAINT FK_ClienteTelefono_Cliente FOREIGN KEY (documento) REFERENCES Cliente (documento) ON DELETE CASCADE,
    CONSTRAINT CK_ClienteTelefono_telefono CHECK (telefono NOT LIKE '%[^0-9]%')
);

-- Especie: "manejamos una lista ... y las que vayan apareciendo" -> tabla, no CHECK.
CREATE TABLE Especie (
    idespecie INT         NOT NULL IDENTITY(1,1),
    nombre    VARCHAR(30) NOT NULL,
    CONSTRAINT PK_Especie PRIMARY KEY (idespecie),
    CONSTRAINT UQ_Especie_nombre UNIQUE (nombre)
);

-- La edad es un atributo derivado: se calcula (fn_EdadMascota), no se guarda.
-- fallecida: la mascota no se borra, queda marcada.
CREATE TABLE Mascota (
    idmascota        INT          NOT NULL IDENTITY(1,1),
    documento        VARCHAR(15)  NOT NULL,
    nombre           VARCHAR(30)  NOT NULL,
    idespecie        INT          NOT NULL,
    raza             VARCHAR(40)  NOT NULL,
    fecha_nacimiento DATE         NOT NULL,
    sexo             CHAR(1)      NOT NULL,                 -- M macho, H hembra
    peso             DECIMAL(5,2) NOT NULL,                 -- peso actual (se actualiza en cada atención)
    microchip        VARCHAR(15)  NULL,                     -- no todas lo tienen
    fallecida        BIT          NOT NULL CONSTRAINT DF_Mascota_fallecida DEFAULT (0),
    CONSTRAINT PK_Mascota PRIMARY KEY (idmascota),
    CONSTRAINT FK_Mascota_Cliente FOREIGN KEY (documento) REFERENCES Cliente (documento),
    CONSTRAINT FK_Mascota_Especie FOREIGN KEY (idespecie) REFERENCES Especie (idespecie),
    CONSTRAINT UQ_Mascota_cliente_nombre UNIQUE (documento, nombre),   -- un cliente no repite nombre de mascota
    CONSTRAINT CK_Mascota_sexo CHECK (sexo IN ('M','H')),
    CONSTRAINT CK_Mascota_peso CHECK (peso > 0),
    CONSTRAINT CK_Mascota_microchip CHECK (LEN(microchip) = 15 AND microchip NOT LIKE '%[^0-9]%')   -- NULL pasa el CHECK
);
-- Microchip opcional pero único cuando existe (igual que el correo).
CREATE UNIQUE INDEX UQ_Mascota_microchip ON Mascota (microchip) WHERE microchip IS NOT NULL;

-- La antigüedad es derivada (fecha_ingreso). activo = 0: se retiró, su historia sigue.
CREATE TABLE Veterinario (
    tarjeta       VARCHAR(10) NOT NULL,
    nombres       VARCHAR(60) NOT NULL,
    apellidos     VARCHAR(60) NOT NULL,
    fecha_ingreso DATE        NOT NULL,
    activo        BIT         NOT NULL CONSTRAINT DF_Veterinario_activo DEFAULT (1),
    CONSTRAINT PK_Veterinario PRIMARY KEY (tarjeta)
);

CREATE TABLE Especialidad (
    idespecialidad INT         NOT NULL IDENTITY(1,1),
    nombre         VARCHAR(40) NOT NULL,
    CONSTRAINT PK_Especialidad PRIMARY KEY (idespecialidad),
    CONSTRAINT UQ_Especialidad_nombre UNIQUE (nombre)
);

-- Veterinario - Especialidad (N:M: "pueden ser varias").
CREATE TABLE VeterinarioEspecialidad (
    tarjeta        VARCHAR(10) NOT NULL,
    idespecialidad INT         NOT NULL,
    CONSTRAINT PK_VeterinarioEspecialidad PRIMARY KEY (tarjeta, idespecialidad),
    CONSTRAINT FK_VeterinarioEspecialidad_Veterinario FOREIGN KEY (tarjeta) REFERENCES Veterinario (tarjeta),
    CONSTRAINT FK_VeterinarioEspecialidad_Especialidad FOREIGN KEY (idespecialidad) REFERENCES Especialidad (idespecialidad)
);

-- Estados permitidos por CHECK. "No se agendan citas hacia atrás" no puede ser
-- un CHECK (los datos históricos tienen fechas pasadas): lo valida sp_AgendarCita.
CREATE TABLE Cita (
    idcita     INT           NOT NULL IDENTITY(1,1),
    idmascota  INT           NOT NULL,
    tarjeta    VARCHAR(10)   NOT NULL,
    fecha_hora DATETIME2(0)  NOT NULL,
    motivo     VARCHAR(100)  NOT NULL,
    estado     CHAR(1)       NOT NULL CONSTRAINT DF_Cita_estado DEFAULT ('P'),   -- P programada, A atendida, C cancelada, N no asistió
    CONSTRAINT PK_Cita PRIMARY KEY (idcita),
    CONSTRAINT FK_Cita_Mascota FOREIGN KEY (idmascota) REFERENCES Mascota (idmascota),
    CONSTRAINT FK_Cita_Veterinario FOREIGN KEY (tarjeta) REFERENCES Veterinario (tarjeta),
    CONSTRAINT CK_Cita_estado CHECK (estado IN ('P','A','C','N'))
);
-- Un veterinario no tiene dos citas a la misma hora; una cita cancelada libera el horario.
CREATE UNIQUE INDEX UQ_Cita_vet_hora ON Cita (tarjeta, fecha_hora) WHERE estado <> 'C';

-- Cita 1:1 Atención: UNIQUE(idcita) = "una cita genera exactamente una atención";
-- NOT NULL = "una atención siempre viene de una cita".
CREATE TABLE Atencion (
    idatencion  INT           NOT NULL IDENTITY(1,1),
    idcita      INT           NOT NULL,
    fecha_hora  DATETIME2(0)  NOT NULL,
    diagnostico VARCHAR(200)  NOT NULL,
    peso        DECIMAL(5,2)  NOT NULL,
    observaciones VARCHAR(200) NULL,
    CONSTRAINT PK_Atencion PRIMARY KEY (idatencion),
    CONSTRAINT UQ_Atencion_idcita UNIQUE (idcita),
    CONSTRAINT FK_Atencion_Cita FOREIGN KEY (idcita) REFERENCES Cita (idcita),
    CONSTRAINT CK_Atencion_peso CHECK (peso > 0)
);

-- Catálogo con subtipos en una sola tabla (tipo = discriminador). CK_Producto_subtipo
-- exige o prohíbe los atributos según el tipo:
--    S servicio     : sin stock, mínimo, conteo, vencimiento ni periodicidad
--    M medicamento  : stock, mínimo, conteo y vencimiento
--    V vacuna       : lo de medicamento + periodicidad en días
--    A accesorio    : stock, mínimo y conteo
-- CK_Producto_stock: el stock nunca queda negativo (un UPDATE que lo intente falla con el 547).
-- conteo_1oct: conteo físico del 1-oct-2026, base de vw_CuadreInventario.
-- descontinuado: un producto se descontinúa, no se borra.
CREATE TABLE Producto (
    codigo        VARCHAR(10)   NOT NULL,
    nombre        VARCHAR(60)   NOT NULL,
    tipo          CHAR(1)       NOT NULL,                  -- S servicio, M medicamento, V vacuna, A accesorio
    precio        DECIMAL(12,2) NOT NULL,
    stock         INT           NULL,
    stock_minimo  INT           NULL,
    conteo_1oct   INT           NULL,
    fecha_vence   DATE          NULL,
    periodicidad  INT           NULL,                      -- días hasta la siguiente dosis
    descontinuado BIT           NOT NULL CONSTRAINT DF_Producto_descontinuado DEFAULT (0),
    CONSTRAINT PK_Producto PRIMARY KEY (codigo),
    CONSTRAINT CK_Producto_tipo CHECK (tipo IN ('S','M','V','A')),
    CONSTRAINT CK_Producto_precio CHECK (precio >= 0),
    CONSTRAINT CK_Producto_stock CHECK (stock >= 0),
    CONSTRAINT CK_Producto_stock_minimo CHECK (stock_minimo >= 0),
    CONSTRAINT CK_Producto_conteo CHECK (conteo_1oct >= 0),
    CONSTRAINT CK_Producto_periodicidad CHECK (periodicidad > 0),
    CONSTRAINT CK_Producto_subtipo CHECK (
           (tipo = 'S' AND stock IS NULL     AND stock_minimo IS NULL     AND conteo_1oct IS NULL
                       AND fecha_vence IS NULL     AND periodicidad IS NULL)
        OR (tipo = 'M' AND stock IS NOT NULL AND stock_minimo IS NOT NULL AND conteo_1oct IS NOT NULL
                       AND fecha_vence IS NOT NULL AND periodicidad IS NULL)
        OR (tipo = 'V' AND stock IS NOT NULL AND stock_minimo IS NOT NULL AND conteo_1oct IS NOT NULL
                       AND fecha_vence IS NOT NULL AND periodicidad IS NOT NULL)
        OR (tipo = 'A' AND stock IS NOT NULL AND stock_minimo IS NOT NULL AND conteo_1oct IS NOT NULL
                       AND fecha_vence IS NULL     AND periodicidad IS NULL))
);

-- Línea de atención: entidad débil de Atención (clave parcial numlinea: 1, 2, 3...
-- dentro de cada atención). precio_unitario se COPIA al cobrar: los precios
-- cambian, la historia no.
CREATE TABLE LineaAtencion (
    idatencion      INT           NOT NULL,
    numlinea        INT           NOT NULL,
    codigo          VARCHAR(10)   NOT NULL,
    cantidad        INT           NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_LineaAtencion PRIMARY KEY (idatencion, numlinea),
    CONSTRAINT FK_LineaAtencion_Atencion FOREIGN KEY (idatencion) REFERENCES Atencion (idatencion),
    CONSTRAINT FK_LineaAtencion_Producto FOREIGN KEY (codigo) REFERENCES Producto (codigo),
    CONSTRAINT CK_LineaAtencion_numlinea CHECK (numlinea >= 1),
    CONSTRAINT CK_LineaAtencion_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_LineaAtencion_precio CHECK (precio_unitario >= 0)
);

-- numfactura NO es IDENTITY: un IDENTITY deja huecos cuando una transacción se
-- revierte y la DIAN exige consecutivo sin huecos. Lo asigna sp_Facturar con
-- MAX + 1 protegido. UNIQUE(idatencion): una atención se factura una sola vez.
-- estado: P pendiente, C cancelada (pagada completa), A anulada (no se borra).
CREATE TABLE Factura (
    numfactura INT           NOT NULL,
    idatencion INT           NOT NULL,
    fecha      DATE          NOT NULL,
    total      DECIMAL(12,2) NOT NULL,
    estado     CHAR(1)       NOT NULL CONSTRAINT DF_Factura_estado DEFAULT ('P'),
    CONSTRAINT PK_Factura PRIMARY KEY (numfactura),
    CONSTRAINT UQ_Factura_idatencion UNIQUE (idatencion),
    CONSTRAINT FK_Factura_Atencion FOREIGN KEY (idatencion) REFERENCES Atencion (idatencion),
    CONSTRAINT CK_Factura_numfactura CHECK (numfactura >= 1),
    CONSTRAINT CK_Factura_total CHECK (total >= 0),
    CONSTRAINT CK_Factura_estado CHECK (estado IN ('P','C','A'))
);

-- Abono. El saldo se calcula (fn_SaldoFactura). "Un pago no puede superar lo que
-- se debe" depende de otras filas: no cabe en un CHECK, lo valida sp_RegistrarPago.
CREATE TABLE Pago (
    idpago     INT           NOT NULL IDENTITY(1,1),
    numfactura INT           NOT NULL,
    fecha_pago DATE          NOT NULL CONSTRAINT DF_Pago_fecha_pago DEFAULT (CAST(SYSDATETIME() AS DATE)),
    monto      DECIMAL(12,2) NOT NULL,
    medio      VARCHAR(13)   NOT NULL,
    CONSTRAINT PK_Pago PRIMARY KEY (idpago),
    CONSTRAINT FK_Pago_Factura FOREIGN KEY (numfactura) REFERENCES Factura (numfactura),
    CONSTRAINT CK_Pago_monto CHECK (monto > 0),
    CONSTRAINT CK_Pago_medio CHECK (medio IN ('Efectivo','Tarjeta','Transferencia'))
);
GO


-- =====================================================================
-- DATOS.  En el orden de las dependencias (padres antes que hijos) y en el
-- orden del enunciado: los identity de Mascota (1-7), Cita (1-7) y
-- Atención (1-4) quedan numerados como en las tablas de la clínica.
-- =====================================================================
INSERT INTO Cliente (documento, nombres, apellidos, correo, calle, ciudad, fecha_cliente) VALUES
('1001','Ana',  'Torres','ana.torres@mail.com','Cra 5 # 10-20',          'Pereira',     '2025-01-15'),
('1002','Bruno','Castro','bruno.c@mail.com',   'Cl 30 # 8-15',           'Dosquebradas','2025-06-02'),
('1003','Carla','Díaz',  'carla.diaz@mail.com','Av 30 de Agosto # 40-10','Pereira',     '2026-02-10'),
('1004','Diego','Ortiz', 'diego.o@mail.com',   'Cl 14 # 23-45',          'Pereira',     '2025-09-20'),
('1005','Elena','Ruiz',  NULL,                 'Cra 12 # 5-30',          'Santa Rosa',  '2026-08-01');

INSERT INTO ClienteTelefono (documento, telefono) VALUES
('1001','3101111111'),
('1001','3101111112'),
('1002','3122222222'),
('1003','3133333333'),
('1004','3144444444'),
('1005','3155555555');

INSERT INTO Especie (nombre) VALUES ('Canino'), ('Felino'), ('Conejo');

INSERT INTO Mascota (documento, nombre, idespecie, raza, fecha_nacimiento, sexo, peso, microchip) VALUES
('1001','Max',  (SELECT idespecie FROM Especie WHERE nombre = 'Canino'),'Labrador',      '2021-04-10','M',28.50,'981000000000001'),
('1001','Luna', (SELECT idespecie FROM Especie WHERE nombre = 'Felino'),'Siamés',        '2022-08-15','H', 4.00,NULL),
('1002','Rocky',(SELECT idespecie FROM Especie WHERE nombre = 'Canino'),'Criollo',       '2019-01-30','M',18.00,'981000000000003'),
('1003','Mia',  (SELECT idespecie FROM Especie WHERE nombre = 'Felino'),'Persa',         '2023-02-20','H', 3.80,NULL),
('1004','Thor', (SELECT idespecie FROM Especie WHERE nombre = 'Canino'),'Pastor alemán', '2020-06-05','M',32.00,NULL),
('1004','Nala', (SELECT idespecie FROM Especie WHERE nombre = 'Felino'),'Criollo',       '2024-05-12','H', 2.90,NULL),
('1005','Coco', (SELECT idespecie FROM Especie WHERE nombre = 'Conejo'),'Enano holandés','2024-01-01','H', 1.50,NULL);

INSERT INTO Veterinario (tarjeta, nombres, apellidos, fecha_ingreso) VALUES
('V01','Laura', 'Gómez','2018-02-01'),
('V02','Andrés','Pérez','2021-07-15'),
('V03','Sofía', 'Rojas','2024-03-01');

INSERT INTO Especialidad (nombre) VALUES ('Medicina general'), ('Cirugía'), ('Dermatología'), ('Odontología');

INSERT INTO VeterinarioEspecialidad (tarjeta, idespecialidad) VALUES
('V01',(SELECT idespecialidad FROM Especialidad WHERE nombre = 'Medicina general')),
('V01',(SELECT idespecialidad FROM Especialidad WHERE nombre = 'Cirugía')),
('V02',(SELECT idespecialidad FROM Especialidad WHERE nombre = 'Dermatología')),
('V03',(SELECT idespecialidad FROM Especialidad WHERE nombre = 'Medicina general')),
('V03',(SELECT idespecialidad FROM Especialidad WHERE nombre = 'Odontología'));

-- El stock cargado es el conteo físico del 1-oct-2026 (conteo_1oct = stock).
INSERT INTO Producto (codigo, nombre, tipo, precio, stock, stock_minimo, conteo_1oct, fecha_vence, periodicidad) VALUES
('S001','Consulta general',    'S',  60000,NULL,NULL,NULL,NULL,        NULL),
('S002','Baño medicado',       'S',  45000,NULL,NULL,NULL,NULL,        NULL),
('S003','Cirugía menor',       'S', 250000,NULL,NULL,NULL,NULL,        NULL),
('M001','Amoxicilina 500 mg',  'M',   8000,  20,  10,  20,'2027-06-30',NULL),
('M002','Antiparasitario oral','M',  15000,   5,   8,   5,'2027-01-31',NULL),
('M003','Analgésico canino',   'M',   6000,  12,   5,  12,'2026-01-31',NULL),
('V001','Vacuna antirrábica',  'V',  35000,  10,   4,  10,'2027-12-31',365),
('V002','Vacuna triple felina','V',  40000,   3,   4,   3,'2027-12-31',365),
('A001','Collar antipulgas',   'A',  25000,   6,   3,   6,NULL,        NULL);

-- Citas 1-7 (mascotas 1-7 según el orden de carga).
-- La cita 6 (Nala) queda 'P' aunque la fecha ya pasó: no vino y nadie la marcó.
INSERT INTO Cita (idmascota, tarjeta, fecha_hora, motivo, estado) VALUES
(1,'V01','2026-03-05 09:00','Vacunación anual',         'A'),
(2,'V03','2025-10-01 10:00','Vacuna triple felina',     'A'),
(5,'V01','2026-09-15 08:00','Herida en pata delantera', 'A'),
(3,'V02','2026-01-20 11:00','Vacuna y control',         'A'),
(4,'V02','2026-11-18 10:00','Picazón y pérdida de pelo','P'),
(6,'V03','2026-10-15 09:00','Control de crecimiento',   'P'),
(3,'V01','2026-10-20 15:00','Limpieza dental',          'C');

INSERT INTO Atencion (idcita, fecha_hora, diagnostico, peso, observaciones) VALUES
(1,'2026-03-05 09:20','Sana. Vacuna antirrábica aplicada.',         28.50,NULL),
(2,'2025-10-01 10:15','Sana. Triple felina aplicada.',               3.90,NULL),
(3,'2026-09-15 08:30','Laceración profunda; sutura bajo sedación.', 32.00,'Control en 10 días'),
(4,'2026-01-20 11:10','Sano. Antirrábica aplicada.',                18.00,NULL);

INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario) VALUES
(1,1,'S001',1, 60000),
(1,2,'V001',1, 35000),
(2,1,'S001',1, 60000),
(2,2,'V002',1, 40000),
(3,1,'S001',1, 60000),
(3,2,'S003',1,250000),
(3,3,'M001',5,  8000),
(3,4,'A001',1, 25000),
(4,1,'S001',1, 60000),
(4,2,'V001',1, 35000);

INSERT INTO Factura (numfactura, idatencion, fecha, total, estado) VALUES
(1,1,'2026-03-05', 95000,'C'),
(2,2,'2025-10-01',100000,'C'),
(3,3,'2026-09-15',375000,'P'),      -- pendiente, sin pagos
(4,4,'2026-01-20', 95000,'C');

INSERT INTO Pago (numfactura, fecha_pago, monto, medio) VALUES
(1,'2026-03-05', 50000,'Efectivo'),
(1,'2026-03-05', 45000,'Tarjeta'),
(2,'2025-10-01',100000,'Transferencia'),
(4,'2026-01-20', 95000,'Efectivo');
GO

-- Foto inicial (anótela): 5 clientes, 6 teléfonos, 3 especies, 7 mascotas,
-- 3 veterinarios, 4 especialidades, 5 especialidades de veterinario,
-- 9 productos, 7 citas, 4 atenciones, 10 líneas, 4 facturas, 4 pagos;
-- stock total 56 unidades; facturado 665 000 y pagado 290 000.
SELECT 'Cliente' AS tabla, COUNT(*) AS filas FROM Cliente
UNION ALL SELECT 'ClienteTelefono', COUNT(*) FROM ClienteTelefono
UNION ALL SELECT 'Especie', COUNT(*) FROM Especie
UNION ALL SELECT 'Mascota', COUNT(*) FROM Mascota
UNION ALL SELECT 'Veterinario', COUNT(*) FROM Veterinario
UNION ALL SELECT 'Especialidad', COUNT(*) FROM Especialidad
UNION ALL SELECT 'VeterinarioEspecialidad', COUNT(*) FROM VeterinarioEspecialidad
UNION ALL SELECT 'Producto', COUNT(*) FROM Producto
UNION ALL SELECT 'Cita', COUNT(*) FROM Cita
UNION ALL SELECT 'Atencion', COUNT(*) FROM Atencion
UNION ALL SELECT 'LineaAtencion', COUNT(*) FROM LineaAtencion
UNION ALL SELECT 'Factura', COUNT(*) FROM Factura
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago;

SELECT SUM(stock) AS stock_total FROM Producto;
SELECT (SELECT SUM(total) FROM Factura) AS facturado, (SELECT SUM(monto) FROM Pago) AS pagado;
-- El total de cada factura debe ser la suma de las líneas de su atención.
SELECT f.numfactura, f.total, SUM(l.cantidad * l.precio_unitario) AS suma_lineas
FROM Factura f
JOIN LineaAtencion l ON l.idatencion = f.idatencion
GROUP BY f.numfactura, f.total
ORDER BY f.numfactura;
GO
--Fin de la foto inicial
--=============================================================================
--CONSULTA 1
SELECT c.nombres + ' ' + c.apellidos AS cliente,
       m.nombre                      AS mascota,
       e.nombre                      AS especie,
       DATEDIFF(YEAR, m.fecha_nacimiento, GETDATE())
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, m.fecha_nacimiento, GETDATE()), m.fecha_nacimiento) > CAST(GETDATE() AS DATE)
                THEN 1 ELSE 0 END    AS edad_anios
FROM Mascota m
JOIN Cliente c ON c.documento = m.documento
JOIN Especie e ON e.idespecie = m.idespecie
ORDER BY c.apellidos, c.nombres, m.nombre;
GO
-- =====================================================================
-- CONSULTA 2
SELECT c.documento,
       c.nombres + ' ' + c.apellidos AS cliente,
       COUNT(f.numfactura)           AS facturas,
       ISNULL(SUM(f.total), 0)       AS total_facturado,
       ISNULL(SUM(p.pagado), 0)      AS total_pagado
FROM Cliente c
LEFT JOIN Mascota  m  ON m.documento  = c.documento
LEFT JOIN Cita     ci ON ci.idmascota = m.idmascota
LEFT JOIN Atencion a  ON a.idcita     = ci.idcita
LEFT JOIN Factura  f  ON f.idatencion = a.idatencion AND f.estado <> 'A'
LEFT JOIN (SELECT numfactura, SUM(monto) AS pagado
           FROM Pago
           GROUP BY numfactura) p ON p.numfactura = f.numfactura
GROUP BY c.documento, c.nombres, c.apellidos
ORDER BY c.documento;
GO
-- =====================================================================
-- CONSULTA 3
SELECT p.codigo, p.nombre, p.stock, p.stock_minimo, p.fecha_vence,
       CASE WHEN p.stock < p.stock_minimo THEN 'Reponer' ELSE 'OK' END AS reposicion,
       CASE WHEN p.fecha_vence IS NULL THEN 'Vigente'
            WHEN p.fecha_vence < CAST(GETDATE() AS DATE) THEN 'VENCIDO'
            WHEN p.fecha_vence <= DATEADD(DAY, 90, CAST(GETDATE() AS DATE)) THEN 'Vence pronto'
            ELSE 'Vigente' END AS vencimiento
FROM Producto p
WHERE p.tipo <> 'S'
  AND (p.stock < p.stock_minimo
       OR p.fecha_vence <= DATEADD(DAY, 90, CAST(GETDATE() AS DATE)))
ORDER BY p.codigo;
GO
-- =====================================================================
-- CONSULTA 4
SELECT m.idmascota, m.nombre AS mascota, c.nombres + ' ' + c.apellidos AS cliente
FROM Mascota m
JOIN Cliente c ON c.documento = m.documento
WHERE NOT EXISTS (SELECT 1
                  FROM Cita ci
                  JOIN Atencion a ON a.idcita = ci.idcita
                  WHERE ci.idmascota = m.idmascota)
ORDER BY m.idmascota;
GO
-- =====================================================================
-- CONSULTA 5
WITH TotalAtencion AS (
    SELECT a.idatencion, ci.tarjeta, SUM(l.cantidad * l.precio_unitario) AS total
    FROM Atencion a
    JOIN Cita ci ON ci.idcita = a.idcita
    JOIN LineaAtencion l ON l.idatencion = a.idatencion
    GROUP BY a.idatencion, ci.tarjeta
)
SELECT v.tarjeta,
       v.nombres + ' ' + v.apellidos AS veterinario,
       COUNT(t.idatencion)           AS atenciones,
       ISNULL(AVG(t.total), 0)       AS valor_promedio,
       ISNULL(MAX(t.total), 0)       AS mayor_valor
FROM Veterinario v
LEFT JOIN TotalAtencion t ON t.tarjeta = v.tarjeta
GROUP BY v.tarjeta, v.nombres, v.apellidos
ORDER BY v.tarjeta;
GO
-- =====================================================================
-- CONSULTA 6
SELECT c.documento, c.nombres + ' ' + c.apellidos AS cliente
FROM Cliente c
WHERE c.documento IN (SELECT m.documento
                      FROM Mascota m
                      JOIN Especie e ON e.idespecie = m.idespecie
                      WHERE e.nombre = 'Canino'
                      INTERSECT
                      SELECT m.documento
                      FROM Mascota m
                      JOIN Especie e ON e.idespecie = m.idespecie
                      WHERE e.nombre = 'Felino')
ORDER BY c.documento;
GO 
-- =====================================================================
-- CONSULTA 7
SELECT m.nombre AS mascota,
       p.nombre AS vacuna,
       CAST(a.fecha_hora AS DATE) AS fecha_aplicacion,
       DATEADD(DAY, p.periodicidad, CAST(a.fecha_hora AS DATE)) AS proxima_dosis,
       CASE WHEN DATEADD(DAY, p.periodicidad, CAST(a.fecha_hora AS DATE)) < CAST(GETDATE() AS DATE)
            THEN 'Vencida' ELSE 'Vigente' END AS estado
FROM LineaAtencion l
JOIN Producto p ON p.codigo     = l.codigo AND p.tipo = 'V'
JOIN Atencion a ON a.idatencion = l.idatencion
JOIN Cita ci    ON ci.idcita    = a.idcita
JOIN Mascota m  ON m.idmascota  = ci.idmascota
ORDER BY proxima_dosis;
GO