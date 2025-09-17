-- Limpieza inicial: Elimina objetos existentes para reiniciar limpio (idempotente con IF EXISTS)
DROP TRIGGER IF EXISTS tr_docente_after_update;
DROP TRIGGER IF EXISTS tr_docente_after_delete;
DROP TABLE IF EXISTS copia_eliminados_docente;
DROP TABLE IF EXISTS copia_actualizados_docente;
DROP TABLE IF EXISTS proyecto;
DROP TABLE IF EXISTS docente;
DROP DATABASE IF EXISTS gestion_proyectos;

-- Crear base de datos si no existe y usarla
CREATE DATABASE IF NOT EXISTS gestion_proyectos;
USE gestion_proyectos;

-- Crear tabla DOCENTE: Almacena información de docentes con constraints para integridad
-- Nota: Los CHECK constraints son soportados desde MySQL 8.0.16; si usas una versión anterior, omite los CHECK
CREATE TABLE docente (
  docente_id INT AUTO_INCREMENT PRIMARY KEY, -- ID único auto-incremental del docente
  numero_documento VARCHAR(20) NOT NULL, -- Número de documento único (e.g., CC, TI)
  nombres VARCHAR(120) NOT NULL, -- Nombres completos del docente
  titulo VARCHAR(120), -- Título académico (e.g., MSc. Sistemas)
  anios_experiencia INT NOT NULL DEFAULT 0, -- Años de experiencia laboral/académica
  direccion VARCHAR(180), -- Dirección residencial
  tipo_docente VARCHAR(40), -- Tipo de vinculación (e.g., Planta, Catedra)
  CONSTRAINT uq_docente_documento UNIQUE (numero_documento), -- Garantiza unicidad del documento
  CONSTRAINT ck_docente_anios CHECK (anios_experiencia >= 0) -- Años de experiencia no negativos
) ENGINE=InnoDB COMMENT 'Tabla principal para docentes';

-- Crear tabla PROYECTO: Almacena proyectos dirigidos por docentes, con relación 1:N
CREATE TABLE proyecto (
  proyecto_id INT AUTO_INCREMENT PRIMARY KEY, -- ID único auto-incremental del proyecto
  nombre VARCHAR(120) NOT NULL, -- Nombre descriptivo del proyecto
  descripcion VARCHAR(400), -- Descripción detallada del proyecto
  fecha_inicial DATE NOT NULL, -- Fecha de inicio obligatoria
  fecha_final DATE, -- Fecha de finalización (puede ser NULL si ongoing)
  presupuesto DECIMAL(12,2) NOT NULL DEFAULT 0, -- Presupuesto asignado en moneda local
  horas INT NOT NULL DEFAULT 0, -- Horas totales estimadas o dedicadas
  docente_id_jefe INT NOT NULL, -- ID del docente responsable (FK)
  CONSTRAINT ck_proyecto_horas CHECK (horas >= 0), -- Horas no negativas
  CONSTRAINT ck_proyecto_presupuesto CHECK (presupuesto >= 0), -- Presupuesto no negativo
  CONSTRAINT ck_proyecto_fechas CHECK (fecha_final IS NULL OR fecha_final >= fecha_inicial), -- Fecha final lógica
  CONSTRAINT fk_proyecto_docente FOREIGN KEY (docente_id_jefe) REFERENCES docente(docente_id)
    ON UPDATE CASCADE ON DELETE RESTRICT -- Relación 1:N; cascade updates, restrict deletes si hay dependencias
) ENGINE=InnoDB COMMENT 'Tabla para proyectos, dependiente de docentes';

-- Crear tablas de auditoría para DOCENTE (seleccionada para triggers)
-- copia_actualizados_docente: Registra versiones actualizadas con timestamp y usuario para rastreo
CREATE TABLE copia_actualizados_docente (
  auditoria_id INT AUTO_INCREMENT PRIMARY KEY, -- ID único de la auditoría
  docente_id INT NOT NULL, -- ID del docente actualizado
  numero_documento VARCHAR(20) NOT NULL, -- Documento en el momento de actualización
  nombres VARCHAR(120) NOT NULL, -- Nombres en el momento de actualización
  titulo VARCHAR(120), -- Título en el momento de actualización
  anios_experiencia INT NOT NULL, -- Años de experiencia en el momento de actualización
  direccion VARCHAR(180), -- Dirección en el momento de actualización
  tipo_docente VARCHAR(40), -- Tipo en el momento de actualización
  accion_fecha DATETIME NOT NULL DEFAULT (UTC_TIMESTAMP()), -- Fecha UTC de la acción para consistencia global
  usuario_sql VARCHAR(128) NOT NULL DEFAULT (CURRENT_USER()) -- Usuario MySQL que realizó la acción
) ENGINE=InnoDB COMMENT 'Auditoría de actualizaciones en docente';

-- copia_eliminados_docente: Registra registros eliminados con timestamp y usuario para recuperación/auditoría
CREATE TABLE copia_eliminados_docente (
  auditoria_id INT AUTO_INCREMENT PRIMARY KEY, -- ID único de la auditoría
  docente_id INT NOT NULL, -- ID del docente eliminado
  numero_documento VARCHAR(20) NOT NULL, -- Documento en el momento de eliminación
  nombres VARCHAR(120) NOT NULL, -- Nombres en el momento de eliminación
  titulo VARCHAR(120), -- Título en el momento de eliminación
  anios_experiencia INT NOT NULL, -- Años de experiencia en el momento de eliminación
  direccion VARCHAR(180), -- Dirección en el momento de eliminación
  tipo_docente VARCHAR(40), -- Tipo en el momento de eliminación
  accion_fecha DATETIME NOT NULL DEFAULT (UTC_TIMESTAMP()), -- Fecha UTC de la acción para consistencia global
  usuario_sql VARCHAR(128) NOT NULL DEFAULT (CURRENT_USER()) -- Usuario MySQL que realizó la acción
) ENGINE=InnoDB COMMENT 'Auditoría de eliminaciones en docente';

-- Crear índices para optimización de queries comunes (e.g., búsquedas por documento o jefe)
CREATE INDEX ix_docente_documento ON docente(numero_documento); -- Índice para búsquedas rápidas por documento
CREATE INDEX ix_proyecto_docente ON proyecto(docente_id_jefe); -- Índice para joins y agregaciones por docente jefe

-- Verificamos la creación de tablas y constraints
SHOW TABLES;
DESCRIBE docente;
DESCRIBE proyecto;

-- Procedimientos para DOCENTE: Limpieza y creación de CRUD
DROP PROCEDURE IF EXISTS sp_docente_crear;
DROP PROCEDURE IF EXISTS sp_docente_leer;
DROP PROCEDURE IF EXISTS sp_docente_actualizar;
DROP PROCEDURE IF EXISTS sp_docente_eliminar;

DELIMITER $$

-- sp_docente_crear: Inserta un nuevo docente y retorna el ID generado
CREATE PROCEDURE sp_docente_crear(
  IN p_numero_documento VARCHAR(20),
  IN p_nombres VARCHAR(120),
  IN p_titulo VARCHAR(120),
  IN p_anios_experiencia INT,
  IN p_direccion VARCHAR(180),
  IN p_tipo_docente VARCHAR(40)
)
BEGIN
  INSERT INTO docente (numero_documento, nombres, titulo, anios_experiencia, direccion, tipo_docente)
  VALUES (p_numero_documento, p_nombres, p_titulo, IFNULL(p_anios_experiencia, 0), p_direccion, p_tipo_docente);
  SELECT LAST_INSERT_ID() AS docente_id_creado;
END$$

-- sp_docente_leer: Lee un docente por ID
CREATE PROCEDURE sp_docente_leer(IN p_docente_id INT)
BEGIN
  SELECT * FROM docente WHERE docente_id = p_docente_id;
END$$

-- sp_docente_actualizar: Actualiza un docente por ID y retorna el registro
CREATE PROCEDURE sp_docente_actualizar(
  IN p_docente_id INT,
  IN p_numero_documento VARCHAR(20),
  IN p_nombres VARCHAR(120),
  IN p_titulo VARCHAR(120),
  IN p_anios_experiencia INT,
  IN p_direccion VARCHAR(180),
  IN p_tipo_docente VARCHAR(40)
)
BEGIN
  UPDATE docente
  SET numero_documento = p_numero_documento,
      nombres = p_nombres,
      titulo = p_titulo,
      anios_experiencia = IFNULL(p_anios_experiencia, 0),
      direccion = p_direccion,
      tipo_docente = p_tipo_docente
  WHERE docente_id = p_docente_id;
  SELECT * FROM docente WHERE docente_id = p_docente_id; -- Simplificado sin CALL
END$$

-- sp_docente_eliminar: Elimina un docente por ID
CREATE PROCEDURE sp_docente_eliminar(IN p_docente_id INT)
BEGIN
  DELETE FROM docente WHERE docente_id = p_docente_id;
END$$

-- Procedimientos para PROYECTO: Limpieza y creación de CRUD
DROP PROCEDURE IF EXISTS sp_proyecto_crear;
DROP PROCEDURE IF EXISTS sp_proyecto_leer;
DROP PROCEDURE IF EXISTS sp_proyecto_actualizar;
DROP PROCEDURE IF EXISTS sp_proyecto_eliminar;

-- sp_proyecto_crear: Inserta un nuevo proyecto y retorna el ID
CREATE PROCEDURE sp_proyecto_crear(
  IN p_nombre VARCHAR(120),
  IN p_descripcion VARCHAR(400),
  IN p_fecha_inicial DATE,
  IN p_fecha_final DATE,
  IN p_presupuesto DECIMAL(12,2),
  IN p_horas INT,
  IN p_docente_id_jefe INT
)
BEGIN
  INSERT INTO proyecto (nombre, descripcion, fecha_inicial, fecha_final, presupuesto, horas, docente_id_jefe)
  VALUES (p_nombre, p_descripcion, p_fecha_inicial, p_fecha_final, IFNULL(p_presupuesto, 0), IFNULL(p_horas, 0), p_docente_id_jefe);
  SELECT LAST_INSERT_ID() AS proyecto_id_creado;
END$$

-- sp_proyecto_leer: Lee un proyecto por ID con join
CREATE PROCEDURE sp_proyecto_leer(IN p_proyecto_id INT)
BEGIN
  SELECT p.*, d.nombres AS nombre_docente_jefe
  FROM proyecto p
  JOIN docente d ON d.docente_id = p.docente_id_jefe
  WHERE p.proyecto_id = p_proyecto_id;
END$$

-- sp_proyecto_actualizar: Actualiza un proyecto por ID y retorna el registro
CREATE PROCEDURE sp_proyecto_actualizar(
  IN p_proyecto_id INT,
  IN p_nombre VARCHAR(120),
  IN p_descripcion VARCHAR(400),
  IN p_fecha_inicial DATE,
  IN p_fecha_final DATE,
  IN p_presupuesto DECIMAL(12,2),
  IN p_horas INT,
  IN p_docente_id_jefe INT
)
BEGIN
  UPDATE proyecto
  SET nombre = p_nombre,
      descripcion = p_descripcion,
      fecha_inicial = p_fecha_inicial,
      fecha_final = p_fecha_final,
      presupuesto = IFNULL(p_presupuesto, 0),
      horas = IFNULL(p_horas, 0),
      docente_id_jefe = p_docente_id_jefe
  WHERE proyecto_id = p_proyecto_id;
  SELECT * FROM proyecto WHERE proyecto_id = p_proyecto_id; -- Simplificado sin CALL
END$$

-- sp_proyecto_eliminar: Elimina un proyecto por ID
CREATE PROCEDURE sp_proyecto_eliminar(IN p_proyecto_id INT)
BEGIN
  DELETE FROM proyecto WHERE proyecto_id = p_proyecto_id;
END$$

DELIMITER ;

-- Datos de prueba: Crear docentes usando procedimiento (20 registros propios)
CALL sp_docente_crear('CC4001', 'Elena Vargas', 'MSc. Computación', 8, 'Av. Central 100', 'Planta');
CALL sp_docente_crear('CC4002', 'Miguel Soto', 'Ing. Software', 5, 'Cra 5 #10-20', 'Catedra');
CALL sp_docente_crear('CC4003', 'Sofia Ramirez', 'PhD. IA', 12, 'Cll 15 #30-40', 'Planta');
CALL sp_docente_crear('CC4004', 'Jorge Mendoza', 'Esp. Datos', 3, 'Av. Norte 200', 'Catedra');
CALL sp_docente_crear('CC4005', 'Laura Ortiz', 'MSc. Redes', 15, 'Cra 8 #50-60', 'Planta');
CALL sp_docente_crear('CC4006', 'Andres Castillo', 'Ing. Sistemas', 7, 'Cll 20 #70-80', 'Catedra');
CALL sp_docente_crear('CC4007', 'Paula Diaz', 'PhD. Educación TI', 10, 'Av. Sur 300', 'Planta');
CALL sp_docente_crear('CC4008', 'Diego Navarro', 'Esp. Seguridad', 4, 'Cra 12 #90-100', 'Catedra');
CALL sp_docente_crear('CC4009', 'Valeria Jimenez', 'MSc. Analítica', 18, 'Cll 25 #110-120', 'Planta');
CALL sp_docente_crear('CC4010', 'Camilo Herrera', 'Ing. Electrónica', 2, 'Av. Este 400', 'Catedra');
CALL sp_docente_crear('CC4011', 'Natalia Cruz', 'MSc. Software', 9, 'Cra 15 #130-140', 'Planta');
CALL sp_docente_crear('CC4012', 'Sergio Lopez', 'PhD. Computación', 6, 'Cll 30 #150-160', 'Catedra');
CALL sp_docente_crear('CC4013', 'Gabriela Torres', 'Esp. IA', 13, 'Av. Oeste 500', 'Planta');
CALL sp_docente_crear('CC4014', 'Ricardo Flores', 'MSc. Datos', 1, 'Cra 18 #170-180', 'Catedra');
CALL sp_docente_crear('CC4015', 'Sara Morales', 'Ing. Sistemas', 16, 'Cll 35 #190-200', 'Planta');
CALL sp_docente_crear('CC4016', 'Mauricio Pena', 'PhD. Redes', 11, 'Av. Central 600', 'Catedra');
CALL sp_docente_crear('CC4017', 'Isabel Rios', 'Esp. Seguridad', 14, 'Cra 20 #210-220', 'Planta');
CALL sp_docente_crear('CC4018', 'Oscar Valdez', 'MSc. Analítica', 19, 'Cll 40 #230-240', 'Catedra');
CALL sp_docente_crear('CC4019', 'Veronica Silva', 'Ing. Software', 20, 'Av. Norte 700', 'Planta');
CALL sp_docente_crear('CC4020', 'Esteban Quintana', 'PhD. Educación', 17, 'Cra 22 #250-260', 'Catedra');

-- Obtener IDs de docentes para asignar a proyectos
SET @id_elena = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4001');
SET @id_miguel = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4002');
SET @id_sofia = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4003');
SET @id_jorge = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4004');
SET @id_laura = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4005');
SET @id_andres = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4006');
SET @id_paula = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4007');
SET @id_diego = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4008');
SET @id_valeria = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4009');
SET @id_camilo = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4010');
SET @id_natalia = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4011');
SET @id_sergio = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4012');
SET @id_gabriela = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4013');
SET @id_ricardo = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4014');
SET @id_sara = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4015');
SET @id_mauricio = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4016');
SET @id_isabel = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4017');
SET @id_oscar = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4018');
SET @id_veronica = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4019');
SET @id_esteban = (SELECT docente_id FROM docente WHERE numero_documento = 'CC4020');

-- Datos de prueba: Crear proyectos usando procedimiento (40 registros con fechas corregidas)
CALL sp_proyecto_crear('Sistema de Gestión Académica 01', 'Plataforma para inscripciones y notas', '2025-01-10', NULL, 30000.00, 150, @id_elena);
CALL sp_proyecto_crear('App de Aprendizaje Móvil 02', 'Aplicación para cursos online', '2025-02-05', '2025-10-15', 45000.00, 200, @id_miguel);
CALL sp_proyecto_crear('Laboratorio Virtual IA 03', 'Simulaciones de machine learning', '2025-03-01', NULL, 50000.00, 180, @id_sofia);
CALL sp_proyecto_crear('Análisis de Datos Educativos 04', 'Dashboards para rendimiento estudiantil', '2025-04-10', '2025-11-20', 35000.00, 160, @id_jorge);
CALL sp_proyecto_crear('Redes Seguras Universitarias 05', 'Implementación de firewalls y VPN', '2025-05-15', NULL, 60000.00, 220, @id_laura);
CALL sp_proyecto_crear('Plataforma de Colaboración 06', 'Herramientas para trabajo en equipo', '2025-06-01', '2025-12-10', 40000.00, 140, @id_andres);
CALL sp_proyecto_crear('Educación Digital Inclusiva 07', 'Contenidos accesibles para discapacitados', '2025-07-05', NULL, 55000.00, 190, @id_paula);
CALL sp_proyecto_crear('Ciberseguridad en Campus 08', 'Entrenamientos y simulaciones de ataques', '2025-08-10', '2026-01-15', 70000.00, 250, @id_diego);
CALL sp_proyecto_crear('Big Data para Investigación 09', 'Almacenamiento y análisis de datasets', '2025-09-01', NULL, 80000.00, 300, @id_valeria);
CALL sp_proyecto_crear('IoT en Aulas Inteligentes 10', 'Sensores para monitoreo ambiental', '2025-10-05', '2026-02-20', 45000.00, 170, @id_camilo);
CALL sp_proyecto_crear('Desarrollo de Software Educativo 11', 'Apps para enseñanza interactiva', '2025-11-10', NULL, 65000.00, 210, @id_natalia);
CALL sp_proyecto_crear('Computación en la Nube 12', 'Migración de servicios a AWS', '2025-12-01', '2026-03-15', 75000.00, 230, @id_sergio);
CALL sp_proyecto_crear('IA para Tutorías 13', 'Chatbots educativos personalizados', '2026-01-05', NULL, 90000.00, 280, @id_gabriela);
CALL sp_proyecto_crear('Minería de Datos Académicos 14', 'Predicciones de deserción', '2026-02-10', '2026-04-20', 55000.00, 190, @id_ricardo);
CALL sp_proyecto_crear('Redes 5G en Campus 15', 'Pruebas y implementación', '2026-03-01', NULL, 85000.00, 260, @id_sara);
CALL sp_proyecto_crear('Realidad Virtual Educativa 16', 'Simulaciones inmersivas', '2026-04-05', '2026-05-15', 95000.00, 320, @id_mauricio);
CALL sp_proyecto_crear('Ética en TI 17', 'Cursos sobre privacidad y datos', '2026-05-10', NULL, 40000.00, 150, @id_isabel);
CALL sp_proyecto_crear('Blockchain para Certificados 18', 'Sistema de verificación digital', '2026-06-01', '2026-06-20', 70000.00, 240, @id_oscar);
CALL sp_proyecto_crear('Analítica Predictiva 19', 'Modelos para optimización curricular', '2026-07-05', NULL, 60000.00, 200, @id_veronica);
CALL sp_proyecto_crear('Robótica Educativa 20', 'Kits para estudiantes', '2026-08-10', '2026-08-20', 50000.00, 180, @id_esteban); -- Corregido: 2026-07-15 -> 2026-08-20
CALL sp_proyecto_crear('E-Learning Avanzado 21', 'Plataformas con gamificación', '2026-09-01', NULL, 75000.00, 220, @id_elena);
CALL sp_proyecto_crear('Seguridad en Apps Móviles 22', 'Auditorías y mejores prácticas', '2026-10-05', '2026-10-15', 65000.00, 210, @id_miguel); -- Corregido: 2026-08-20 -> 2026-10-15
CALL sp_proyecto_crear('Machine Learning Aplicado 23', 'Proyectos en visión computacional', '2026-11-10', NULL, 85000.00, 250, @id_sofia);
CALL sp_proyecto_crear('Bases de Datos Distribuidas 24', 'Implementación con NoSQL', '2026-12-01', '2027-01-15', 55000.00, 190, @id_jorge); -- Corregido: 2026-09-15 -> 2027-01-15
CALL sp_proyecto_crear('Ciberdefensa Universitaria 25', 'Equipo de respuesta a incidentes', '2027-01-05', NULL, 90000.00, 280, @id_laura);
CALL sp_proyecto_crear('Colaboración en Línea 26', 'Herramientas open-source', '2027-02-10', '2027-03-15', 45000.00, 160, @id_andres); -- Corregido: 2026-10-20 -> 2027-03-15
CALL sp_proyecto_crear('Inclusión Digital 27', 'Programas para comunidades rurales', '2027-03-01', NULL, 60000.00, 200, @id_paula);
CALL sp_proyecto_crear('Simuladores de Redes 28', 'Entornos virtuales para práctica', '2027-04-05', '2027-05-15', 70000.00, 230, @id_diego); -- Corregido: 2026-11-15 -> 2027-05-15
CALL sp_proyecto_crear('Data Warehousing 29', 'Almacenes para análisis histórico', '2027-05-10', NULL, 80000.00, 260, @id_valeria);
CALL sp_proyecto_crear('Smart Campus IoT 30', 'Integración de dispositivos inteligentes', '2027-06-01', '2027-07-15', 95000.00, 300, @id_camilo); -- Corregido: 2026-12-20 -> 2027-07-15
CALL sp_proyecto_crear('Software Libre en Educación 31', 'Adopción y capacitación', '2027-07-05', NULL, 50000.00, 180, @id_natalia);
CALL sp_proyecto_crear('Cloud Computing Educativo 32', 'Recursos para estudiantes', '2027-08-10', '2027-09-15', 65000.00, 210, @id_sergio); -- Corregido: 2027-01-15 -> 2027-09-15
CALL sp_proyecto_crear('Bots Educativos 33', 'Asistentes virtuales para consultas', '2027-09-01', NULL, 75000.00, 240, @id_gabriela);
CALL sp_proyecto_crear('Data Mining en Currículos 34', 'Análisis para mejoras', '2027-10-05', '2027-11-15', 55000.00, 190, @id_ricardo); -- Corregido: 2027-02-20 -> 2027-11-15
CALL sp_proyecto_crear('5G para Educación Remota 35', 'Pruebas de conectividad', '2027-11-10', NULL, 85000.00, 250, @id_sara);
CALL sp_proyecto_crear('VR en Clases 36', 'Experiencias inmersivas', '2027-12-01', '2028-01-15', 90000.00, 280, @id_mauricio); -- Corregido: 2027-03-15 -> 2028-01-15
CALL sp_proyecto_crear('Privacidad en Datos 37', 'Políticas y entrenamiento', '2028-01-05', NULL, 40000.00, 150, @id_isabel);
CALL sp_proyecto_crear('Certificados Digitales 38', 'Sistema basado en blockchain', '2028-02-10', '2028-04-20', 70000.00, 230, @id_oscar); -- Corregido: 2027-04-20 -> 2028-04-20
CALL sp_proyecto_crear('Predictiva en Educación 39', 'Modelos para éxito estudiantil', '2028-03-01', NULL, 60000.00, 200, @id_veronica);
CALL sp_proyecto_crear('Robots en Laboratorios 40', 'Automatización de experimentos', '2028-04-05', '2028-06-15', 50000.00, 170, @id_esteban); -- Corregido: 2027-05-15 -> 2028-06-15

-- Pruebas: Verificar inserts básicos
SELECT * FROM docente LIMIT 5;  -- Ver primeros docentes
SELECT * FROM proyecto LIMIT 5;  -- Ver primeros proyectos

-- Prueba CRUD para DOCENTE: Leer, Actualizar (activa trigger update), Eliminar (activa trigger delete, pero primero eliminar proyectos dependientes por FK restrict)
CALL sp_docente_leer(1);  -- Leer docente 1
CALL sp_docente_actualizar(1, 'CC4001', 'Elena Vargas Actualizada', 'PhD. Computación', 10, 'Av. Central 100 Nueva', 'Planta');  -- Actualizar y verificar trigger
DELETE FROM proyecto WHERE docente_id_jefe = 1;  -- Eliminar proyectos dependientes
CALL sp_docente_eliminar(1);  -- Eliminar y verificar trigger

-- Prueba CRUD para PROYECTO: Leer, Actualizar, Eliminar
CALL sp_proyecto_leer(2);  -- Leer proyecto 2 con join
CALL sp_proyecto_actualizar(2, 'App de Aprendizaje Móvil Actualizada', 'Aplicación mejorada', '2025-02-05', '2025-12-31', 50000.00, 250, @id_miguel);  -- Actualizar
CALL sp_proyecto_eliminar(2);  -- Eliminar

-- Prueba triggers: Verificar auditoría después de update/delete
SELECT * FROM copia_actualizados_docente ORDER BY auditoria_id DESC LIMIT 5;  -- Últimas actualizaciones
SELECT * FROM copia_eliminados_docente ORDER BY auditoria_id DESC LIMIT 5;  -- Últimas eliminaciones

-- Pruebas adicionales: Joins, agregaciones, validaciones
-- Q1: Proyectos y su docente jefe
SELECT p.proyecto_id, p.nombre AS proyecto, d.nombres AS docente_jefe FROM proyecto p JOIN docente d ON d.docente_id = p.docente_id_jefe LIMIT 5;
-- Q2: Total de presupuesto por docente
SELECT d.docente_id, d.nombres, SUM(p.presupuesto) AS total_presupuesto FROM docente d LEFT JOIN proyecto p ON d.docente_id = p.docente_id_jefe GROUP BY d.docente_id LIMIT 5;
-- Q3: Validar CHECKs (todos los proyectos deben cumplir)
SELECT * FROM proyecto WHERE NOT (fecha_final IS NULL OR fecha_final >= fecha_inicial) OR presupuesto < 0 OR horas < 0;  -- Debe retornar 0 rows si OK
-- Q4: Docentes sin proyectos
SELECT d.* FROM docente d LEFT JOIN proyecto p ON d.docente_id = p.docente_id_jefe WHERE p.proyecto_id IS NULL;


-- Verifica los datos;
SELECT proyecto_id, nombre, fecha_inicial, fecha_final FROM proyecto;

-- Limpieza y creación de UDF
DROP FUNCTION IF EXISTS fn_promedio_horas_por_docente;

DELIMITER $$
-- fn_promedio_horas_por_docente: Calcula el promedio de horas por proyecto para un docente dado.
-- Lógica de negocio: Ayuda a evaluar la carga laboral promedio por proyecto asignado al docente.
-- Operación matemática: AVG sobre horas; retorna 0 si no hay proyectos o datos insuficientes.
CREATE FUNCTION fn_promedio_horas_por_docente(p_docente_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_promedio DECIMAL(10,2);
  -- Consulta promedio de horas de proyectos donde el docente es jefe
  SELECT IFNULL(AVG(horas), 0) INTO v_promedio
  FROM proyecto
  WHERE docente_id_jefe = p_docente_id;
  -- Retornar el valor, asegurando 0 en casos nulos
  RETURN v_promedio;
END$$
DELIMITER ;

SELECT fn_promedio_horas_por_docente(1);

DELIMITER $$
-- tr_docente_after_update: Trigger que se activa después de una actualización en docente.
-- Propósito: Registra la nueva versión en copia_actualizados_docente para auditoría histórica.
CREATE TRIGGER tr_docente_after_update
AFTER UPDATE ON docente
FOR EACH ROW
BEGIN
  -- Insertar la versión actualizada (NEW) en la tabla de auditoría; accion_fecha y usuario_sql se auto-llenan
  INSERT INTO copia_actualizados_docente
    (docente_id, numero_documento, nombres, titulo, anios_experiencia, direccion, tipo_docente)
  VALUES
    (NEW.docente_id, NEW.numero_documento, NEW.nombres, NEW.titulo, NEW.anios_experiencia, NEW.direccion, NEW.tipo_docente);
END$$

-- tr_docente_after_delete: Trigger que se activa después de una eliminación en docente.
-- Propósito: Registra la versión eliminada (OLD) en copia_eliminados_docente para recuperación o compliance.
CREATE TRIGGER tr_docente_after_delete
AFTER DELETE ON docente
FOR EACH ROW
BEGIN
  -- Insertar la versión eliminada (OLD) en la tabla de auditoría; accion_fecha y usuario_sql se auto-llenan
  INSERT INTO copia_eliminados_docente
    (docente_id, numero_documento, nombres, titulo, anios_experiencia, direccion, tipo_docente)
  VALUES
    (OLD.docente_id, OLD.numero_documento, OLD.nombres, OLD.titulo, OLD.anios_experiencia, OLD.direccion, OLD.tipo_docente);
END$$
DELIMITER ;