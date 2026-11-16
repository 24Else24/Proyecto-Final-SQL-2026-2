/* =====================================================================
   Desarrollo de Bases de Datos 2026-2
   TALLER 20 %: Clínica veterinaria VetAmigos
   Variante: A Agenda     D = 1     Cédulas: 1011512001, 543875

   Códigos
      Cita.estado       P programada, A atendida, C cancelada, N no asistió
      Factura.estado    P pendiente, C cancelada (pagada completa), A anulada
      Producto.tipo     S servicio, M medicamento, V vacuna, A accesorio
      Mascota.sexo      M macho, H hembra*/
-- =====================================================================
-- PASO 0.
-- =====================================================================
USE master;
GO
IF DB_ID('VetAmigos') IS NOT NULL
BEGIN
    ALTER DATABASE VetAmigos SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE VetAmigos;
END
CREATE DATABASE VetAmigos;
GO
USE VetAmigos;
GO

CREATE TABLE Cliente (
    documento     VARCHAR(15)  NOT NULL,
    nombres       VARCHAR(60)  NOT NULL,
    apellidos     VARCHAR(60)  NOT NULL,
    correo        VARCHAR(100) NULL,         
    calle         VARCHAR(100) NOT NULL,   
    ciudad        VARCHAR(30)  NOT NULL,
    fecha_cliente DATE         NOT NULL CONSTRAINT DF_Cliente_fecha_cliente DEFAULT (CAST(SYSDATETIME() AS DATE)),
    CONSTRAINT PK_Cliente PRIMARY KEY (documento),
    CONSTRAINT CK_Cliente_correo CHECK (correo LIKE '%_@_%._%')       -- NULL pasa el CHECK
);
CREATE UNIQUE INDEX UQ_Cliente_correo ON Cliente (correo) WHERE correo IS NOT NULL;
GO

CREATE TABLE ClienteTelefono (
    documento VARCHAR(15) NOT NULL,
    telefono  VARCHAR(15) NOT NULL,
    CONSTRAINT PK_ClienteTelefono PRIMARY KEY (documento, telefono),
    CONSTRAINT FK_ClienteTelefono_Cliente FOREIGN KEY (documento) REFERENCES Cliente (documento) ON DELETE CASCADE,
    CONSTRAINT CK_ClienteTelefono_telefono CHECK (telefono NOT LIKE '%[^0-9]%')
);

CREATE TABLE Especie (
    idespecie INT         NOT NULL IDENTITY(1,1),
    nombre    VARCHAR(30) NOT NULL,
    CONSTRAINT PK_Especie PRIMARY KEY (idespecie),
    CONSTRAINT UQ_Especie_nombre UNIQUE (nombre)
);

CREATE TABLE Mascota (
    idmascota        INT          NOT NULL IDENTITY(1,1),
    documento        VARCHAR(15)  NOT NULL,
    nombre           VARCHAR(30)  NOT NULL,
    idespecie        INT          NOT NULL,
    raza             VARCHAR(40)  NOT NULL,
    fecha_nacimiento DATE         NOT NULL,
    sexo             CHAR(1)      NOT NULL,                 
    peso             DECIMAL(5,2) NOT NULL,                 
    microchip        VARCHAR(15)  NULL,                     
    fallecida        BIT          NOT NULL CONSTRAINT DF_Mascota_fallecida DEFAULT (0),
    CONSTRAINT PK_Mascota PRIMARY KEY (idmascota),
    CONSTRAINT FK_Mascota_Cliente FOREIGN KEY (documento) REFERENCES Cliente (documento),
    CONSTRAINT FK_Mascota_Especie FOREIGN KEY (idespecie) REFERENCES Especie (idespecie),
    CONSTRAINT UQ_Mascota_cliente_nombre UNIQUE (documento, nombre),   -- un cliente no repite nombre de mascota
    CONSTRAINT CK_Mascota_sexo CHECK (sexo IN ('M','H')),
    CONSTRAINT CK_Mascota_peso CHECK (peso > 0),
    CONSTRAINT CK_Mascota_microchip CHECK (LEN(microchip) = 15 AND microchip NOT LIKE '%[^0-9]%')   -- NULL pasa el CHECK
);
CREATE UNIQUE INDEX UQ_Mascota_microchip ON Mascota (microchip) WHERE microchip IS NOT NULL;

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

CREATE TABLE VeterinarioEspecialidad (
    tarjeta        VARCHAR(10) NOT NULL,
    idespecialidad INT         NOT NULL,
    CONSTRAINT PK_VeterinarioEspecialidad PRIMARY KEY (tarjeta, idespecialidad),
    CONSTRAINT FK_VeterinarioEspecialidad_Veterinario FOREIGN KEY (tarjeta) REFERENCES Veterinario (tarjeta),
    CONSTRAINT FK_VeterinarioEspecialidad_Especialidad FOREIGN KEY (idespecialidad) REFERENCES Especialidad (idespecialidad)
);

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

CREATE TABLE LogError (
    idlog         INT            NOT NULL IDENTITY(1,1),
    fecha         DATETIME2(0)   NOT NULL CONSTRAINT DF_LogError_fecha DEFAULT (SYSDATETIME()),
    usuario       SYSNAME        NOT NULL CONSTRAINT DF_LogError_usuario DEFAULT (SUSER_SNAME()),
    procedimiento SYSNAME        NULL,          -- ERROR_PROCEDURE()
    numero        INT            NOT NULL,      -- ERROR_NUMBER()
    linea         INT            NULL,          -- ERROR_LINE()
    mensaje       NVARCHAR(2048) NOT NULL,      -- ERROR_MESSAGE()
    parametros    VARCHAR(200)   NULL,          -- con qué datos se llamó
    CONSTRAINT PK_LogError PRIMARY KEY (idlog)
);

CREATE TABLE Auditoria (
    idaud         INT           NOT NULL IDENTITY(1,1),
    fecha         DATETIME2(0)  NOT NULL CONSTRAINT DF_Auditoria_fecha DEFAULT (SYSDATETIME()),
    usuario       SYSNAME       NOT NULL CONSTRAINT DF_Auditoria_usuario DEFAULT (ORIGINAL_LOGIN()),
    programa      NVARCHAR(128) NOT NULL CONSTRAINT DF_Auditoria_programa DEFAULT (APP_NAME()),
    codigo        VARCHAR(10)   NOT NULL,
    operacion     CHAR(1)       NULL,
    stock_antes   INT           NULL,
    stock_despues INT           NULL,
    CONSTRAINT PK_Auditoria PRIMARY KEY (idaud)
);
GO

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
(3,3,'2026-09-15',375000,'P'),      
(4,4,'2026-01-20', 95000,'C');

INSERT INTO Pago (numfactura, fecha_pago, monto, medio) VALUES
(1,'2026-03-05', 50000,'Efectivo'),
(1,'2026-03-05', 45000,'Tarjeta'),
(2,'2025-10-01',100000,'Transferencia'),
(4,'2026-01-20', 95000,'Efectivo');
GO
--==============================================================================
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


--FUNCIOES
CREATE FUNCTION fn_EdadMascota (@fecha_nacimiento DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @fecha_nacimiento, GETDATE())
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @fecha_nacimiento, GETDATE()), @fecha_nacimiento) > CAST(GETDATE() AS DATE)
                THEN 1 ELSE 0 END;
END
GO

CREATE FUNCTION fn_SaldoFactura (@numfactura INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @saldo DECIMAL(12,2);
    SELECT @saldo = f.total - ISNULL((SELECT SUM(p.monto) FROM Pago p WHERE p.numfactura = f.numfactura), 0)
    FROM Factura f
    WHERE f.numfactura = @numfactura;
    RETURN @saldo;
END
GO

CREATE FUNCTION fn_HistoriaMascota (@idmascota INT)
RETURNS TABLE
AS
RETURN
(
    SELECT a.idatencion,
           a.fecha_hora,
           v.nombres + ' ' + v.apellidos AS veterinario,
           a.diagnostico,
           ISNULL(t.total, 0)            AS total,
           f.numfactura
    FROM Atencion a
    JOIN Cita ci        ON ci.idcita     = a.idcita
    JOIN Veterinario v  ON v.tarjeta     = ci.tarjeta
    LEFT JOIN Factura f ON f.idatencion  = a.idatencion
    LEFT JOIN (SELECT idatencion, SUM(cantidad * precio_unitario) AS total
               FROM LineaAtencion
               GROUP BY idatencion) t ON t.idatencion = a.idatencion
    WHERE ci.idmascota = @idmascota
);
GO

CREATE FUNCTION fn_CitasVetDia (@tarjeta VARCHAR(10), @fecha DATE)
RETURNS INT
AS
BEGIN
    DECLARE @n INT;
    SELECT @n = COUNT(*)
    FROM Cita
    WHERE tarjeta = @tarjeta
      AND estado <> 'C'
      AND fecha_hora >= @fecha
      AND fecha_hora <  DATEADD(DAY, 1, @fecha);
    RETURN @n;
END
GO

--Vistas
CREATE VIEW vw_ResumenCliente AS
SELECT c.documento,
       c.nombres + ' ' + c.apellidos AS cliente,
       (SELECT COUNT(*)
        FROM Mascota m
        WHERE m.documento = c.documento AND m.fallecida = 0) AS mascotas_activas,
       (SELECT COUNT(*)
        FROM Mascota m
        JOIN Cita ci ON ci.idmascota = m.idmascota
        JOIN Atencion a ON a.idcita = ci.idcita
        WHERE m.documento = c.documento) AS atenciones,
       (SELECT ISNULL(SUM(f.total), 0)
        FROM Mascota m
        JOIN Cita ci ON ci.idmascota = m.idmascota
        JOIN Atencion a ON a.idcita = ci.idcita
        JOIN Factura f ON f.idatencion = a.idatencion
        WHERE m.documento = c.documento AND f.estado <> 'A') AS facturado,
       (SELECT ISNULL(SUM(dbo.fn_SaldoFactura(f.numfactura)), 0)
        FROM Mascota m
        JOIN Cita ci ON ci.idmascota = m.idmascota
        JOIN Atencion a ON a.idcita = ci.idcita
        JOIN Factura f ON f.idatencion = a.idatencion
        WHERE m.documento = c.documento AND f.estado = 'P') AS saldo_pendiente
FROM Cliente c;
GO

CREATE VIEW vw_CuadreInventario AS
SELECT p.codigo, p.nombre, p.stock, p.conteo_1oct,
       ISNULL(d.despachado, 0)                             AS despachado_desde_1oct,
       p.conteo_1oct - ISNULL(d.despachado, 0)             AS stock_esperado,
       p.stock - (p.conteo_1oct - ISNULL(d.despachado, 0)) AS diferencia
FROM Producto p
LEFT JOIN (SELECT l.codigo, SUM(l.cantidad) AS despachado
           FROM LineaAtencion l
           JOIN Atencion a ON a.idatencion = l.idatencion
           WHERE a.fecha_hora >= '2026-10-01'
           GROUP BY l.codigo) d ON d.codigo = p.codigo
WHERE p.tipo <> 'S';
GO

CREATE VIEW vw_AgendaDia AS
SELECT ci.idcita, ci.fecha_hora,
       m.nombre                      AS mascota,
       c.nombres + ' ' + c.apellidos AS cliente,
       v.nombres + ' ' + v.apellidos AS veterinario,
       ci.motivo,
       dbo.fn_CitasVetDia(ci.tarjeta, CAST(ci.fecha_hora AS DATE)) AS citas_vet_dia
FROM Cita ci
JOIN Mascota m     ON m.idmascota = ci.idmascota
JOIN Cliente c     ON c.documento = m.documento
JOIN Veterinario v ON v.tarjeta   = ci.tarjeta
WHERE ci.estado = 'P'
  AND ci.fecha_hora >= CAST(GETDATE() AS DATE);
GO


--Procedimintos
CREATE OR ALTER PROCEDURE sp_AgendarCita
(
    @idmascota  INT,
    @tarjeta    VARCHAR(10),
    @fecha_hora DATETIME2(0),
    @motivo     VARCHAR(100),
    @idcita     INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @idcita = NULL;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Mascota WHERE idmascota = @idmascota)
            THROW 50001, 'La mascota no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Veterinario WHERE tarjeta = @tarjeta AND activo = 1)
            THROW 50001, 'El veterinario no existe o está inactivo.', 1;
        IF @fecha_hora < SYSDATETIME()
            THROW 50020, 'No se puede agendar una cita en el pasado.', 1;

        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM Cita
                       WHERE idmascota = @idmascota
                         AND estado = 'P'
                         AND CAST(fecha_hora AS DATE) = CAST(@fecha_hora AS DATE))
                THROW 50010, 'La mascota ya tiene una cita programada ese día.', 1;

            -- Si el veterinario ya tiene 3 citas ese día, el trigger lanza 50011.
            INSERT INTO Cita (idmascota, tarjeta, fecha_hora, motivo)
            VALUES (@idmascota, @tarjeta, @fecha_hora, @motivo);
            SET @idcita = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT idcita, fecha_hora, estado FROM Cita WHERE idcita = @idcita;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @idcita = NULL;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idmascota=', @idmascota, ' tarjeta=', @tarjeta,
                       ' fecha=', CONVERT(VARCHAR(19), @fecha_hora, 120)));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_CancelarCita
(
    @idcita INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @estado CHAR(1);

        BEGIN TRANSACTION;
            SELECT @estado = estado FROM Cita WITH (UPDLOCK) WHERE idcita = @idcita;

            IF @estado IS NULL
                THROW 50001, 'La cita no existe.', 1;
            IF @estado <> 'P'
                THROW 50002, 'Solo se pueden cancelar citas programadas (P).', 1;

            UPDATE Cita SET estado = 'C' WHERE idcita = @idcita;
        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idcita=', @idcita));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_RegistrarAtencion
(
    @idcita         INT,
    @diagnostico    VARCHAR(200),
    @peso           DECIMAL(5,2),
    @observaciones  VARCHAR(200) = NULL,
    @idatencion     INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @idatencion = NULL;
    BEGIN TRY
        DECLARE @estado CHAR(1), @idmascota INT;

        BEGIN TRANSACTION;
            SELECT @estado = estado, @idmascota = idmascota
            FROM Cita WITH (UPDLOCK) WHERE idcita = @idcita;

            IF @estado IS NULL
                THROW 50001, 'La cita no existe.', 1;
            IF @estado <> 'P'
                THROW 50002, 'Solo se pueden atender citas programadas (P).', 1;
            IF EXISTS (SELECT 1 FROM Atencion WHERE idcita = @idcita)
                THROW 50006, 'Ya existe una atención para esa cita.', 1;

            INSERT INTO Atencion (idcita, fecha_hora, diagnostico, peso, observaciones)
            VALUES (@idcita, SYSDATETIME(), @diagnostico, @peso, @observaciones);
            SET @idatencion = SCOPE_IDENTITY();

            -- Línea 1: la consulta general, al precio de hoy.
            INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario)
            SELECT @idatencion, 1, codigo, 1, precio
            FROM Producto WHERE codigo = 'S001';
            IF @@ROWCOUNT = 0
                THROW 50001, 'No existe el servicio S001 (consulta general).', 1;

            UPDATE Cita     SET estado = 'A' WHERE idcita = @idcita;
            UPDATE Mascota  SET peso   = @peso WHERE idmascota = @idmascota;
        COMMIT TRANSACTION;

        SELECT idatencion, idcita, fecha_hora FROM Atencion WHERE idatencion = @idatencion;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @idatencion = NULL;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idcita=', @idcita, ' peso=', @peso));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AgregarItem
(
    @idatencion INT,
    @codigo     VARCHAR(10),
    @cantidad   INT,
    @demora_seg INT = 0,
    @numlinea   INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @numlinea = NULL;
    BEGIN TRY
        IF @cantidad <= 0
            THROW 50020, 'La cantidad debe ser mayor que cero.', 1;

        DECLARE @tipo CHAR(1), @precio DECIMAL(12,2), @descontinuado BIT,
                @filas INT, @n INT,
                -- WAITFOR DELAY no acepta un INT: hay que darle 'hh:mm:ss'
                @espera CHAR(8) = CONVERT(CHAR(8),
                                  DATEADD(SECOND, ISNULL(@demora_seg, 0), CAST('00:00:00' AS TIME(0))), 108);

        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM Atencion WHERE idatencion = @idatencion)
                THROW 50001, 'La atención no existe.', 1;
            IF EXISTS (SELECT 1 FROM Factura WHERE idatencion = @idatencion)
                THROW 50003, 'La atención ya está facturada.', 1;

            SELECT @tipo = tipo, @precio = precio, @descontinuado = descontinuado
            FROM Producto WHERE codigo = @codigo;

            IF @tipo IS NULL
                THROW 50001, 'El producto no existe.', 1;
            IF @descontinuado = 1
                THROW 50004, 'El producto no está disponible (descontinuado).', 1;

            IF @tipo <> 'S'     
            BEGIN
                UPDATE Producto
                SET stock = stock - @cantidad
                WHERE codigo = @codigo AND stock >= @cantidad;
                SET @filas = @@ROWCOUNT;

                IF @filas = 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    RETURN 3;               
                END
            END

            IF @demora_seg > 0
                WAITFOR DELAY @espera;      

            SET @n = ISNULL((SELECT MAX(numlinea) FROM LineaAtencion WHERE idatencion = @idatencion), 0) + 1;
            INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario)
            VALUES (@idatencion, @n, @codigo, @cantidad, @precio);
            SET @numlinea = @n;

        COMMIT TRANSACTION;

        SELECT numlinea, codigo, cantidad, precio_unitario
        FROM LineaAtencion WHERE idatencion = @idatencion AND numlinea = @numlinea;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @numlinea = NULL;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idatencion=', @idatencion, ' codigo=', @codigo, ' cant=', @cantidad));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_Facturar
(
    @idatencion  INT,
    @numfactura  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @numfactura = NULL;
    BEGIN TRY
        DECLARE @total DECIMAL(12,2);

        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM Atencion WHERE idatencion = @idatencion)
                THROW 50001, 'La atención no existe.', 1;
            IF EXISTS (SELECT 1 FROM Factura WHERE idatencion = @idatencion)
                THROW 50003, 'La atención ya está facturada.', 1;

            SELECT @total = SUM(cantidad * precio_unitario)
            FROM LineaAtencion WHERE idatencion = @idatencion;
            IF @total IS NULL
                THROW 50020, 'La atención no tiene líneas; no se puede facturar.', 1;

            SELECT @numfactura = ISNULL(MAX(numfactura), 0) + 1
            FROM Factura WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO Factura (numfactura, idatencion, fecha, total, estado)
            VALUES (@numfactura, @idatencion, CAST(SYSDATETIME() AS DATE), @total, 'P');

        COMMIT TRANSACTION;

        SELECT numfactura, total, estado FROM Factura WHERE numfactura = @numfactura;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @numfactura = NULL;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idatencion=', @idatencion));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_RegistrarPago
(
    @numfactura INT,
    @monto      DECIMAL(12,2),
    @medio      VARCHAR(13),
    @idpago     INT OUTPUT,
    @saldo      DECIMAL(12,2) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @idpago = NULL; SET @saldo = NULL;
    BEGIN TRY
        IF @monto <= 0
            THROW 50020, 'El monto debe ser mayor que cero.', 1;
        IF @medio NOT IN ('Efectivo','Tarjeta','Transferencia')
            THROW 50020, 'Medio de pago inválido.', 1;

        DECLARE @estado CHAR(1), @actual DECIMAL(12,2);

        BEGIN TRANSACTION;

            SELECT @estado = estado FROM Factura WITH (UPDLOCK, HOLDLOCK)
            WHERE numfactura = @numfactura;

            IF @estado IS NULL
                THROW 50001, 'La factura no existe.', 1;
            IF @estado <> 'P'
                THROW 50005, 'La factura no está pendiente.', 1;

            SET @actual = dbo.fn_SaldoFactura(@numfactura);
            IF @monto > @actual
            BEGIN
                SET @saldo = @actual;
                ROLLBACK TRANSACTION;
                RETURN 3;                   
            END

            INSERT INTO Pago (numfactura, monto, medio)
            VALUES (@numfactura, @monto, @medio);
            SET @idpago = SCOPE_IDENTITY();

            SET @saldo = dbo.fn_SaldoFactura(@numfactura);
            IF @saldo = 0
                UPDATE Factura SET estado = 'C' WHERE numfactura = @numfactura;

        COMMIT TRANSACTION;

        SELECT @idpago as  idpago, saldo = @saldo;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @idpago = NULL; SET @saldo = NULL;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('numfactura=', @numfactura, ' monto=', @monto, ' medio=', @medio));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_MarcarInasistencias
(
    @fecha    DATE = NULL,
    @marcadas INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @marcadas = 0;
    BEGIN TRY
        DECLARE @hoy DATE = ISNULL(@fecha, CAST(SYSDATETIME() AS DATE));
        DECLARE @idcita INT, @fh DATETIME2(0), @mascota VARCHAR(30);
        DECLARE @procesadas TABLE (idcita INT, fecha_hora DATETIME2(0), mascota VARCHAR(30));

        DECLARE cur_inasist CURSOR LOCAL FAST_FORWARD FOR
            SELECT ci.idcita, ci.fecha_hora, m.nombre
            FROM Cita ci
            JOIN Mascota m ON m.idmascota = ci.idmascota
            WHERE ci.estado = 'P'
              AND ci.fecha_hora < @hoy
            ORDER BY ci.fecha_hora;

        OPEN cur_inasist;
        FETCH NEXT FROM cur_inasist INTO @idcita, @fh, @mascota;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;
                    UPDATE Cita SET estado = 'N' WHERE idcita = @idcita AND estado = 'P';
                COMMIT TRANSACTION;

                SET @marcadas += 1;
                INSERT INTO @procesadas VALUES (@idcita, @fh, @mascota);
                PRINT CONCAT('No asistió: cita ', @idcita, ' (', @mascota, ') del ',
                             CONVERT(VARCHAR(19), @fh, 120));
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
                VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                        CONCAT('idcita=', @idcita));
                PRINT CONCAT('ERROR en cita ', @idcita, ': ', ERROR_MESSAGE());
            END CATCH

            FETCH NEXT FROM cur_inasist INTO @idcita, @fh, @mascota;
        END
        CLOSE cur_inasist;
        DEALLOCATE cur_inasist;

        SELECT idcita, fecha_hora, mascota FROM @procesadas ORDER BY fecha_hora;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('fecha=', CONVERT(VARCHAR(10), @fecha, 120)));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AgregarItemInseguro
(
    @idatencion INT,
    @codigo     VARCHAR(10),
    @cantidad   INT,
    @demora_seg INT = 0,
    @numlinea   INT = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @numlinea = NULL;
    BEGIN TRY
        IF @cantidad <= 0
            THROW 50020, 'La cantidad debe ser mayor que cero.', 1;
        IF NOT EXISTS (SELECT 1 FROM Atencion WHERE idatencion = @idatencion)
            THROW 50001, 'La atención no existe.', 1;

        DECLARE @tipo CHAR(1), @precio DECIMAL(12,2), @stock INT, @n INT,
                @espera CHAR(8) = CONVERT(CHAR(8),
                                  DATEADD(SECOND, ISNULL(@demora_seg, 0), CAST('00:00:00' AS TIME(0))), 108);

        SELECT @tipo = tipo, @precio = precio, @stock = stock      
        FROM Producto WHERE codigo = @codigo;
        IF @tipo IS NULL
            THROW 50001, 'El producto no existe.', 1;

        IF @demora_seg > 0
            WAITFOR DELAY @espera;                                  

        IF @tipo <> 'S'
            UPDATE Producto SET stock = @stock - @cantidad          
            WHERE codigo = @codigo;

        SET @n = ISNULL((SELECT MAX(numlinea) FROM LineaAtencion WHERE idatencion = @idatencion), 0) + 1;
        INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario)
        VALUES (@idatencion, @n, @codigo, @cantidad, @precio);
        SET @numlinea = @n;

        SELECT numlinea, codigo, cantidad, precio_unitario
        FROM LineaAtencion WHERE idatencion = @idatencion AND numlinea = @numlinea;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('INSEGURO idatencion=', @idatencion, ' codigo=', @codigo));
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_DespacharKit
(
    @idatencion INT,
    @codigo1    VARCHAR(10),
    @codigo2    VARCHAR(10),
    @demora_seg INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @tipo CHAR(1), @precio DECIMAL(12,2), @descontinuado BIT,
                @filas INT, @n INT,
                @espera CHAR(8) = CONVERT(CHAR(8),
                                  DATEADD(SECOND, ISNULL(@demora_seg, 0), CAST('00:00:00' AS TIME(0))), 108);

        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM Atencion WHERE idatencion = @idatencion)
                THROW 50001, 'La atención no existe.', 1;
            IF EXISTS (SELECT 1 FROM Factura WHERE idatencion = @idatencion)
                THROW 50003, 'La atención ya está facturada.', 1;

            -- ===== Producto 1 =====
            SELECT @tipo = tipo, @precio = precio, @descontinuado = descontinuado
            FROM Producto WHERE codigo = @codigo1;
            IF @tipo IS NULL
                THROW 50001, 'El producto 1 no existe.', 1;
            IF @descontinuado = 1
                THROW 50004, 'El producto 1 no está disponible.', 1;

            IF @tipo <> 'S'
            BEGIN
                UPDATE Producto SET stock = stock - 1 WHERE codigo = @codigo1 AND stock >= 1;
                SET @filas = @@ROWCOUNT;
                IF @filas = 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    RETURN 3;
                END
            END
            SET @n = ISNULL((SELECT MAX(numlinea) FROM LineaAtencion WHERE idatencion = @idatencion), 0) + 1;
            INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario)
            VALUES (@idatencion, @n, @codigo1, 1, @precio);

            -- ===== Demora ENTRE los dos productos =====
            IF @demora_seg > 0
                WAITFOR DELAY @espera;

            -- ===== Producto 2 =====
            SELECT @tipo = tipo, @precio = precio, @descontinuado = descontinuado
            FROM Producto WHERE codigo = @codigo2;
            IF @tipo IS NULL
                THROW 50001, 'El producto 2 no existe.', 1;
            IF @descontinuado = 1
                THROW 50004, 'El producto 2 no está disponible.', 1;

            IF @tipo <> 'S'
            BEGIN
                UPDATE Producto SET stock = stock - 1 WHERE codigo = @codigo2 AND stock >= 1;
                SET @filas = @@ROWCOUNT;
                IF @filas = 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    RETURN 3;
                END
            END
            SET @n = ISNULL((SELECT MAX(numlinea) FROM LineaAtencion WHERE idatencion = @idatencion), 0) + 1;
            INSERT INTO LineaAtencion (idatencion, numlinea, codigo, cantidad, precio_unitario)
            VALUES (@idatencion, @n, @codigo2, 1, @precio);

        COMMIT TRANSACTION;

        SELECT codigo, cantidad
        FROM (VALUES (@codigo1, 1), (@codigo2, 1)) AS k(codigo, cantidad);
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO LogError (procedimiento, numero, linea, mensaje, parametros)
        VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_LINE(), ERROR_MESSAGE(),
                CONCAT('idatencion=', @idatencion, ' kit=', @codigo1, '+', @codigo2));
        THROW;
    END CATCH
END
GO


--Triggers
CREATE OR ALTER TRIGGER TR_Producto_Auditoria ON Producto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO Auditoria (operacion, codigo, stock_antes, stock_despues)
    SELECT CASE WHEN d.codigo IS NULL THEN 'I'      
                WHEN i.codigo IS NULL THEN 'D'      
                ELSE 'U' END,                      
           COALESCE(i.codigo, d.codigo), d.stock, i.stock
    FROM inserted i
    FULL JOIN deleted d ON d.codigo = i.codigo
    WHERE ISNULL(i.stock, -1) <> ISNULL(d.stock, -1)    
       OR (i.codigo IS NULL OR d.codigo IS NULL);        
END
GO

CREATE OR ALTER TRIGGER TR_Cita_MaxVetDia ON Cita
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE i.estado <> 'C'
                 AND dbo.fn_CitasVetDia(i.tarjeta, CAST(i.fecha_hora AS DATE)) > (1 + 2))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50011, 'El veterinario no puede tener más de 3 citas no canceladas el mismo día.', 1;
    END
END
GO
--roles

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_1011512001')
    CREATE LOGIN app_1011512001 WITH PASSWORD = 'App#1011512001!';
GO
CREATE USER app_1011512001 FOR LOGIN app_1011512001;
GO
 
CREATE ROLE rol_app;
GRANT EXECUTE ON sp_AgendarCita          TO rol_app;
GRANT EXECUTE ON sp_CancelarCita         TO rol_app;
GRANT EXECUTE ON sp_RegistrarAtencion    TO rol_app;
GRANT EXECUTE ON sp_AgregarItem          TO rol_app;
GRANT EXECUTE ON sp_Facturar             TO rol_app;
GRANT EXECUTE ON sp_RegistrarPago        TO rol_app;
GRANT EXECUTE ON sp_MarcarInasistencias  TO rol_app;
GRANT EXECUTE ON sp_AgregarItemInseguro  TO rol_app;
GRANT EXECUTE ON sp_DespacharKit         TO rol_app;
GRANT SELECT  ON vw_ResumenCliente       TO rol_app;
GRANT SELECT  ON vw_CuadreInventario     TO rol_app;
GRANT SELECT  ON vw_AgendaDia            TO rol_app;
GRANT SELECT  ON fn_HistoriaMascota      TO rol_app;      
ALTER ROLE rol_app ADD MEMBER app_1011512001;
GO

-- Rol de la variante A: agenda y cancela citas y lee la agenda; no factura ni registra nig pago.
CREATE ROLE rol_recepcion;
GRANT EXECUTE ON sp_AgendarCita          TO rol_recepcion;
GRANT EXECUTE ON sp_CancelarCita         TO rol_recepcion;
GRANT SELECT  ON vw_AgendaDia            TO rol_recepcion;
GO
-- Usuario de prueba sin login: solo existe dentro de VetAmigos pa pruebas.
CREATE USER u_recepcion WITHOUT LOGIN;
ALTER ROLE rol_recepcion ADD MEMBER u_recepcion;
GO

/*============================================PRUEBAS=====================================*/
-- ---------- T1. Agendar cita: Coco con V01, 2026-12-01 10:00 ----------
-- Esperado: RETURN 0 y cita número 8.
DECLARE @rc INT, @idcita INT;
EXEC @rc = sp_AgendarCita @idmascota = 7, @tarjeta = 'V01', @fecha_hora = '2026-12-01 10:00',
                          @motivo = 'Control general', @idcita = @idcita OUTPUT;
SELECT @rc AS retorno, @idcita AS idcita;
GO
 
-- ---------- T2. Atender la cita 5 (Mia) ----------
-- Esperado: atención 5; cita 5 en estado A; línea 1 = S001 a 60000.00; peso de Mia 4.20.
DECLARE @rc INT, @idatencion INT;
EXEC @rc = sp_RegistrarAtencion @idcita = 5, @diagnostico = 'Dermatitis alérgica', @peso = 4.20,
                                @idatencion = @idatencion OUTPUT;
SELECT @rc AS retorno, @idatencion AS idatencion;
SELECT idcita, estado FROM Cita WHERE idcita = 5;
SELECT idatencion, numlinea, codigo, cantidad, precio_unitario FROM LineaAtencion WHERE idatencion = 5;
SELECT nombre, peso FROM Mascota WHERE idmascota = 4;
GO
 
-- ---------- T3. Agregar 2 unidades de M001 a la atención 5 ----------
-- Esperado: línea 2; stock de M001 = 18; Auditoria: M001 20 -> 18.
DECLARE @rc INT, @n INT;
EXEC @rc = sp_AgregarItem @idatencion = 5, @codigo = 'M001', @cantidad = 2, @numlinea = @n OUTPUT;
SELECT @rc AS retorno, @n AS numlinea;
SELECT codigo, stock FROM Producto WHERE codigo = 'M001';
SELECT codigo, stock_antes, stock_despues, usuario, programa FROM Auditoria ORDER BY idaud;
GO
 
-- ---------- T4. Agregar 1 unidad de V002 ----------
-- Esperado: línea 3; stock de V002 = 2 (queda BAJO el mínimo de 4); Auditoria: V002 3 -> 2.
DECLARE @rc INT, @n INT;
EXEC @rc = sp_AgregarItem @idatencion = 5, @codigo = 'V002', @cantidad = 1, @numlinea = @n OUTPUT;
SELECT @rc AS retorno, @n AS numlinea;
SELECT codigo, stock, stock_minimo FROM Producto WHERE codigo = 'V002';
SELECT codigo, stock_antes, stock_despues FROM Auditoria ORDER BY idaud;
GO
 
-- ---------- T5. Agregar 6 unidades de M002 (hay 5) ----------
-- Esperado: RETURN 3 (no alcanza el stock; no es un error, es una regla de negocio).
-- Stock de M002 sigue en 5; sin fila nueva en LogError ni en Auditoria.
DECLARE @rc INT, @n INT;
EXEC @rc = sp_AgregarItem @idatencion = 5, @codigo = 'M002', @cantidad = 6, @numlinea = @n OUTPUT;
SELECT @rc AS retorno, @n AS numlinea;
SELECT codigo, stock FROM Producto WHERE codigo = 'M002';
GO
 
-- ---------- T6. Atender la cita 2 (ya atendida) ----------
-- Esperado: ERROR 50002 "Solo se pueden atender citas programadas (P)."; fila en LogError.
BEGIN TRY
    DECLARE @rc INT, @ida INT;
    EXEC @rc = sp_RegistrarAtencion @idcita = 2, @diagnostico = 'Prueba', @peso = 3.90, @idatencion = @ida OUTPUT;
    SELECT @rc AS retorno;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH
SELECT TOP 1 idlog, numero, procedimiento, mensaje, parametros FROM LogError ORDER BY idlog DESC;
GO
 
-- ---------- T7. Facturar la atención 5 y registrar pagos ----------
-- Esperado: factura 5 por 116000.00 (60000 + 2 x 8000 + 40000).
DECLARE @rc INT, @nf INT;
EXEC @rc = sp_Facturar @idatencion = 5, @numfactura = @nf OUTPUT;
SELECT @rc AS retorno, @nf AS numfactura;
GO
-- Pago de 100000 con tarjeta. Esperado: RETURN 0, saldo 16000.00, factura sigue en P.
DECLARE @rc INT, @idpago INT, @saldo DECIMAL(12,2);
EXEC @rc = sp_RegistrarPago @numfactura = 5, @monto = 100000, @medio = 'Tarjeta',
                            @idpago = @idpago OUTPUT, @saldo = @saldo OUTPUT;
SELECT @rc AS retorno, @idpago AS idpago, @saldo AS saldo;
SELECT numfactura, total, estado FROM Factura WHERE numfactura = 5;
GO
-- Pago de 20000 (supera el saldo de 16000). Esperado: RETURN 3, saldo 16000.00 y NO se
-- registra el pago; la factura sigue en P.
DECLARE @rc INT, @idpago INT, @saldo DECIMAL(12,2);
EXEC @rc = sp_RegistrarPago @numfactura = 5, @monto = 20000, @medio = 'Efectivo',
                            @idpago = @idpago OUTPUT, @saldo = @saldo OUTPUT;
SELECT @rc AS retorno, @idpago AS idpago, @saldo AS saldo;
SELECT numfactura, total, estado FROM Factura WHERE numfactura = 5;
GO
 
-- ---------- T8. Regla de la variante A (D = 1: máximo D + 2 = 3 citas por día) ----------
-- Citas de V02 el 2026-12-02 a las 08:00, 09:00, 10:00... hasta que una falle.
-- Esperado: Max (cita 9), Luna (cita 10) y Rocky (cita 11) pasan, RETURN 0 cada una.
DECLARE @rc INT, @idcita INT;
EXEC @rc = sp_AgendarCita @idmascota = 1, @tarjeta = 'V02', @fecha_hora = '2026-12-02 08:00', @motivo = 'Control', @idcita = @idcita OUTPUT;
SELECT @rc AS retorno, @idcita AS idcita;
GO
DECLARE @rc INT, @idcita INT;
EXEC @rc = sp_AgendarCita @idmascota = 2, @tarjeta = 'V02', @fecha_hora = '2026-12-02 09:00', @motivo = 'Control', @idcita = @idcita OUTPUT;
SELECT @rc AS retorno, @idcita AS idcita;
GO
DECLARE @rc INT, @idcita INT;
EXEC @rc = sp_AgendarCita @idmascota = 3, @tarjeta = 'V02', @fecha_hora = '2026-12-02 10:00', @motivo = 'Control', @idcita = @idcita OUTPUT;
SELECT @rc AS retorno, @idcita AS idcita;
GO
-- La cuarta (Thor, 11:00) falla en el TRIGGER: ERROR 50011 (más de 3 citas el mismo día).
-- Se revierte el INSERT, pero el número 12 del IDENTITY ya se consumió (el próximo será 13).
-- Fila en LogError porque el trigger se disparó dentro del procedimiento.
BEGIN TRY
    DECLARE @rc INT, @idcita INT;
    EXEC @rc = sp_AgendarCita @idmascota = 5, @tarjeta = 'V02', @fecha_hora = '2026-12-02 11:00', @motivo = 'Control', @idcita = @idcita OUTPUT;
    SELECT @rc AS retorno, @idcita AS idcita;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_PROCEDURE() AS objeto, ERROR_MESSAGE() AS mensaje;
END CATCH
SELECT TOP 1 idlog, numero, procedimiento, mensaje FROM LogError ORDER BY idlog DESC;
GO
-- Otra cita para Max el 2-dic a las 14:00 (ya tiene la de las 08:00 programada).
-- Esperado: ERROR 50010 en el procedimiento (se valida ANTES de insertar: no consume número).
BEGIN TRY
    DECLARE @rc INT, @idcita INT;
    EXEC @rc = sp_AgendarCita @idmascota = 1, @tarjeta = 'V02', @fecha_hora = '2026-12-02 14:00', @motivo = 'Otra', @idcita = @idcita OUTPUT;
    SELECT @rc AS retorno, @idcita AS idcita;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_PROCEDURE() AS objeto, ERROR_MESSAGE() AS mensaje;
END CATCH
SELECT TOP 1 idlog, numero, procedimiento, mensaje FROM LogError ORDER BY idlog DESC;
GO
 
-- ---------- T9. Proceso por lotes: sp_MarcarInasistencias ----------
-- Citas programadas cuya fecha ya pasó: solo la 6 (Nala, 2026-10-15).
-- Esperado: RETURN 0, @marcadas = 1; la cita 6 queda en estado N.
DECLARE @rc INT, @marcadas INT;
EXEC @rc = sp_MarcarInasistencias @fecha = NULL, @marcadas = @marcadas OUTPUT;
SELECT @rc AS retorno, @marcadas AS marcadas;
SELECT idcita, estado FROM Cita WHERE idcita = 6;
GO
-- Segunda ejecución. Esperado: @marcadas = 0 (ya no queda ninguna).
DECLARE @rc INT, @marcadas INT;
EXEC @rc = sp_MarcarInasistencias @fecha = NULL, @marcadas = @marcadas OUTPUT;
SELECT @rc AS retorno, @marcadas AS marcadas;
GO
 
-- ---------- T10. Permisos con rol_recepcion (usuario u_recepcion) ----------
-- Regla de la clase: REVERT va SOLO en el lote siguiente.
-- Operación PERMITIDA: leer la agenda. Esperado: 4 filas (citas 8, 9, 10 y 11).
EXECUTE AS USER = 'u_recepcion';
SELECT USER_NAME() AS usuario, ORIGINAL_LOGIN() AS login_original;
SELECT idcita, fecha_hora, mascota, cliente, veterinario, citas_vet_dia FROM vw_AgendaDia ORDER BY fecha_hora;
GO
REVERT;
GO
-- Operación NEGADA: facturar. Esperado: Msg 229, "The EXECUTE permission was denied
-- on the object 'sp_Facturar'".
EXECUTE AS USER = 'u_recepcion';
BEGIN TRY
    DECLARE @rc INT, @nf INT;
    EXEC @rc = sp_Facturar @idatencion = 5, @numfactura = @nf OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH
GO
REVERT;
GO
-- También negada: leer la tabla directamente. Esperado: Msg 229 sobre Cliente.
EXECUTE AS USER = 'u_recepcion';
BEGIN TRY
    SELECT * FROM Cliente;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH
GO
REVERT;
GO
 
-- ---------- Estado al terminar T1-T9 (anótelo; se coteja en la sustentación) ----------
-- Esperado: 11 citas, 5 atenciones, 13 líneas, 5 facturas, 5 pagos, 53 unidades en stock,
-- 3 filas en LogError (T6, T8 con 50011 y T8 con 50010), 2 filas en Auditoria (T3, T4)
-- y vw_CuadreInventario con diferencia 0 en todo.
SELECT 'Cita' AS tabla, COUNT(*) AS filas FROM Cita
UNION ALL SELECT 'Atencion', COUNT(*) FROM Atencion
UNION ALL SELECT 'LineaAtencion', COUNT(*) FROM LineaAtencion
UNION ALL SELECT 'Factura', COUNT(*) FROM Factura
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago
UNION ALL SELECT 'LogError', COUNT(*) FROM LogError
UNION ALL SELECT 'Auditoria', COUNT(*) FROM Auditoria;
SELECT SUM(stock) AS stock_total FROM Producto;
SELECT * FROM vw_CuadreInventario ORDER BY codigo;
SELECT * FROM vw_ResumenCliente ORDER BY documento;
GO