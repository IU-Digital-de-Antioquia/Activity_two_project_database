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