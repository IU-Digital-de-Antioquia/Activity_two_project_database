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