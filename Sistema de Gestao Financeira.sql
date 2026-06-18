---Tabelas
CREATE TABLE usuario(
    id_usuario    NUMBER PRIMARY KEY,
    nome_usuario  VARCHAR2(100),
    email         VARCHAR2(100) UNIQUE,
    profissao     VARCHAR2(100),
    data_registro DATE DEFAULT SYSDATE
  );
CREATE TABLE categoria(
    id_categoria     NUMBER PRIMARY KEY,
    nome_categoria   VARCHAR2(50) UNIQUE,
    nivel_prioridade NUMBER CHECK (nivel_prioridade BETWEEN 1 AND 3)
  );
CREATE TABLE despesas
  (
    id_despesa       NUMBER PRIMARY KEY,
    id_usuario       NUMBER,
    id_categoria     NUMBER,
    descricao        VARCHAR2(255),
    valor            NUMBER(10, 2),
    valor_pago       NUMBER(10, 2) DEFAULT 0,         -- Valor j� pago da despesa
    valor_por_pagar  NUMBER(10,2),                    -- valor por ser pago;
    status_pagamento VARCHAR2(10) DEFAULT 'pendente', -- 'pendente' ou 'quitado'
    mes_referencia   VARCHAR2(7) DEFAULT TO_CHAR(SYSDATE, 'MM/YYYY'),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
  );
CREATE TABLE orcamento
  (
    id_orcamento    NUMBER PRIMARY KEY,
    id_usuario      NUMBER,
    mes_referencia  VARCHAR2(7) DEFAULT TO_CHAR(SYSDATE, 'MM/YYYY'),
    valor_orcamento NUMBER(10, 2),
    saldo_restante  NUMBER(10, 2),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
    UNIQUE (id_usuario, mes_referencia)
  );
COMMIT;

---Triggers
---Trigger para definir por padrao o valor por pagar depois de inserir uma despesa
CREATE OR REPLACE TRIGGER tgr_valor_por_pagar
BEFORE INSERT ON despesas
FOR EACH ROW
BEGIN 
  :NEW.valor_por_pagar := :NEW.valor;
END;
/
---Trigger para definir o saldo que resta no orcamento criado, zerando o mes passado e passando o saldo para o mes em curso
CREATE OR REPLACE TRIGGER tgr_saldo_restante
BEFORE INSERT ON ORCAMENTO
FOR EACH ROW 
DECLARE 
  v_saldo_restante_anterior NUMBER;
BEGIN
    SELECT NVL(saldo_restante, 0)
    INTO v_saldo_restante_anterior
    FROM ORCAMENTO
    WHERE id_usuario     = :NEW.id_usuario
    AND mes_referencia   = TO_CHAR(ADD_MONTHS(TO_DATE(:NEW.mes_referencia, 'MM/YYYY'), -1), 'MM/YYYY');
    
    :NEW.SALDO_RESTANTE := v_saldo_restante_anterior + :NEW.VALOR_ORCAMENTO;
    
    UPDATE ORCAMENTO
    SET SALDO_RESTANTE   = 0
    WHERE mes_referencia = TO_CHAR(ADD_MONTHS(TO_DATE(:NEW.mes_referencia, 'MM/YYYY'), -1), 'MM/YYYY');
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :NEW.SALDO_RESTANTE := :NEW.VALOR_ORCAMENTO;
  END;
/
  ------As despesas nao podem ser superior ao orcamento trigger de verificar orcamento antes de criar despesa
CREATE OR REPLACE TRIGGER trg_verifica_orcamento
BEFORE INSERT OR UPDATE OF valor ON despesas
FOR EACH ROW
DECLARE
  v_total_despesas NUMBER(10, 2);
  v_orcamento NUMBER(10, 2);
BEGIN
    SELECT NVL(SUM(valor), 0)
    INTO v_total_despesas
    FROM despesas
    WHERE id_usuario   = :NEW.id_usuario
    AND mes_referencia = :NEW.mes_referencia;
    
    SELECT valor_orcamento
    INTO v_orcamento
    FROM orcamento
    WHERE id_usuario  = :NEW.id_usuario
    AND mes_referencia  = :NEW.mes_referencia;
    IF v_total_despesas  + :NEW.valor > v_orcamento THEN
      RAISE_APPLICATION_ERROR(-20001,'O valor das despesas totais ultrapassam o valor do or�amento.');
    END IF;
  END;
/
  ---- Trigger para atualizar o status da despesa assim que essa for paga completamente
CREATE OR REPLACE TRIGGER trg_atualiza_status_pagamento
BEFORE UPDATE OF valor_por_pagar ON despesas
FOR EACH ROW
BEGIN
  IF :NEW.VALOR_POR_PAGAR = 0 THEN
    :NEW.STATUS_PAGAMENTO := 'quitado';
END IF;
END;
/
-------------Funcoes
-----funcao para VERIFICAR DESPESAS DO MES PASSADO
CREATE OR REPLACE FUNCTION func_verifica_despesas_passado
  RETURN NUMBER
IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM despesas
  WHERE status_pagamento = 'pendente'
  AND mes_referencia     = TO_CHAR(ADD_MONTHS(SYSDATE, -1), 'MM/YYYY');
  
  IF v_count             > 0 THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END;
/

CREATE OR REPLACE FUNCTION verificar_despesas_essencial
RETURN NUMBER
IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM DESPESAS
  WHERE ID_CATEGORIA   = 1
  AND STATUS_PAGAMENTO = 'pendente';
  IF v_count           > 0 THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END;
/
CREATE OR REPLACE FUNCTION verificar_despesas_importante
RETURN NUMBER
IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM DESPESAS
  WHERE ID_CATEGORIA   = 2
  AND STATUS_PAGAMENTO = 'pendente';
  IF v_count           > 0 THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END;
/
--------Inserts
INSERT INTO USUARIO(id_usuario, nome_usuario, email, profissao)
VALUES(1, 'Edson', 'edson.augusto@easan.co.mz', 'IT Technician');
COMMIT;

SELECT * FROM USUARIO;
--DELETE FROM USUARIO;

INSERT INTO CATEGORIA VALUES(1,'Essencial',1);
INSERT INTO CATEGORIA VALUES(2,'Importante',2);
INSERT INTO CATEGORIA VALUES(3,'Opcional',3);
COMMIT;

SELECT * FROM CATEGORIA;

INSERT INTO ORCAMENTO(id_orcamento,id_usuario,valor_orcamento)VALUES(1,1,20306.56);
---orcamento do mes seguinte
INSERT INTO ORCAMENTO(id_orcamento,id_usuario,valor_orcamento)VALUES (2,1,16307.69);
COMMIT;
--DELETE FROM ORCAMENTO;
SELECT * FROM ORCAMENTO;

----Criar despesas
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor)VALUES(1,1,1,'Transporte',5200);
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor) VALUES(2,1,1,'Mensalidade',3750);
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor) VALUES(3,1,2,'Credito',500);
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor) VALUES(4,1,3,'Passeio',1500);
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor) VALUES(5,1,3,'Presente',800);

---despesa que ultrapassa o orcamento
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor)VALUES(9,1,1,'Comprar computador',24000);
----despesa dentro do orcamento
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor)VALUES(6,1,2,'Gas',950);
---despesas do mes seguinte
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor)VALUES(7,1,2,'Gas',950);
INSERT INTO DESPESAS(id_despesa,id_usuario,id_categoria,descricao,valor)VALUES(8,1,1,'Mensalidade',3750);

COMMIT;
SELECT * FROM despesas;

delete despesas;
---relatorio
CREATE OR REPLACE PROCEDURE relatorio_mensal IS
v_despesas_total NUMBER;
v_despesas_quitadas NUMBER;
v_despesas_pendentes NUMBER;
v_total_pago NUMBER;
v_total_porpagar NUMBER;

BEGIN
SELECT COUNT (*) INTO v_despesas_total FROM DESPESAS
WHERE MES_REFERENCIA = TO_CHAR(SYSDATE, 'MM/YYYY');

SELECT COUNT (*) INTO v_despesas_quitadas FROM DESPESAS
WHERE MES_REFERENCIA = TO_CHAR(SYSDATE, 'MM/YYYY')
AND STATUS_PAGAMENTO = 'quitado';

SELECT COUNT (*) INTO v_despesas_pendentes  FROM DESPESAS
WHERE MES_REFERENCIA = TO_CHAR(SYSDATE, 'MM/YYYY')
AND STATUS_PAGAMENTO = 'pendente';

SELECT NVL(SUM(VALOR_PAGO),0)
INTO v_total_pago FROM DESPESAS
WHERE MES_REFERENCIA = TO_CHAR(SYSDATE, 'MM/YYYY');

SELECT NVL(SUM(VALOR_POR_PAGAR),0)
INTO v_total_porpagar FROM DESPESAS
WHERE MES_REFERENCIA = TO_CHAR(SYSDATE, 'MM/YYYY');

DBMS_OUTPUT.PUT_LINE('Relatorio Mensal das Despesas
DESPESAS TOTAL: '||v_despesas_total||'
DESPESAS QUITADAS: '||v_despesas_quitadas||'
DESPESAS PENDENTES: '||v_despesas_pendentes||'
TOTAL VALOR PAGO: '||v_total_pago||'
TOTAL VALOR POR PAGAR: '||v_total_porpagar);
END;
/
------Pagamento
CREATE OR REPLACE PROCEDURE pagamento(p_valor IN NUMBER, p_despesa_id IN NUMBER)IS
  v_valor_a_pagar           NUMBER(10,2);
  v_status_despesa          VARCHAR2(20);
  v_categoria_despesa       NUMBER;
  v_id_usuario              NUMBER(10);
  v_saldo                   NUMBER(10,2);
  v_despesa_passado         NUMBER;
  v_valor_soma              NUMBER;
  
  inserir_valor_negativo    EXCEPTION;
  inserir_valor_acima       EXCEPTION;
  efetuar_pagamento_quitado EXCEPTION;
  inserir_pagamento_maior   EXCEPTION;

BEGIN
  SELECT ID_USUARIO
  INTO v_id_usuario
  FROM DESPESAS
  WHERE ID_DESPESA = p_despesa_id;
  
  SELECT NVL(SUM(SALDO_RESTANTE), 0)
  INTO v_saldo
  FROM ORCAMENTO
  WHERE ID_USUARIO = v_id_usuario;
  
  SELECT STATUS_PAGAMENTO
  INTO v_status_despesa
  FROM DESPESAS
  WHERE ID_DESPESA = p_despesa_id;
  
  SELECT VALOR_POR_PAGAR
  INTO v_valor_a_pagar
  FROM DESPESAS
  WHERE ID_DESPESA = p_despesa_id;
  
  SELECT ID_CATEGORIA
  INTO v_categoria_despesa
  FROM DESPESAS
  WHERE ID_DESPESA = p_despesa_id;
  
  IF v_status_despesa = 'quitado' THEN
    RAISE efetuar_pagamento_quitado;
  END IF;
  IF v_valor_a_pagar < p_valor THEN
    RAISE inserir_pagamento_maior;
  END IF;
  IF p_valor < 0 THEN
    RAISE inserir_valor_negativo;
  END IF;
  IF p_valor > v_saldo THEN
    RAISE inserir_valor_acima;
  END IF;
  
  IF func_verifica_despesas_passado() = 1 THEN
    SELECT SUM(VALOR_POR_PAGAR)
    INTO v_despesa_passado
    FROM DESPESAS
    WHERE mes_referencia = TO_CHAR(ADD_MONTHS(SYSDATE, -1), 'MM/YYYY')
    AND status_pagamento = 'pendente'
    AND ID_USUARIO = v_id_usuario;
    
    UPDATE DESPESAS
    SET valor_pago       = valor_pago + valor_por_pagar,
    valor_por_pagar    = 0
    WHERE ID_USUARIO     = v_id_usuario
    AND mes_referencia   = TO_CHAR(ADD_MONTHS(SYSDATE, -1), 'MM/YYYY')
    AND status_pagamento = 'pendente';
    
    UPDATE ORCAMENTO
    SET SALDO_RESTANTE = SALDO_RESTANTE - v_despesa_passado
    WHERE ID_USUARIO   = v_id_usuario
    AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
    
    DBMS_OUTPUT.PUT_LINE('PAGAMENTOS DAS DESPESAS DO MES PASSADO QUITADAS COM SUCESSO!');
  END IF;
  
  IF v_categoria_despesa = 2 THEN
    IF verificar_despesas_essencial() = 1 THEN
      SELECT SUM(VALOR_POR_PAGAR)
      INTO v_valor_soma
      FROM DESPESAS
      WHERE ID_CATEGORIA   = 1
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE DESPESAS
      SET valor_pago = valor_pago + valor_por_pagar, valor_por_pagar = 0
      WHERE ID_CATEGORIA = 1
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE ORCAMENTO
      SET SALDO_RESTANTE = SALDO_RESTANTE - v_valor_soma
      WHERE ID_USUARIO   = v_id_usuario
      AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
      
      DBMS_OUTPUT.PUT_LINE('PAGAMENTOS DAS DESPESAS ESSENCIAIS QUITADAS COM SUCESSO!');
    END IF;
  END IF;
  
  IF v_categoria_despesa = 3 THEN
    IF verificar_despesas_essencial() = 1 THEN
      SELECT SUM(VALOR_POR_PAGAR)
      INTO v_valor_soma
      FROM DESPESAS
      WHERE ID_CATEGORIA   = 1
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE DESPESAS
      SET valor_pago = valor_pago + valor_por_pagar, valor_por_pagar = 0
      WHERE ID_CATEGORIA = 1
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE ORCAMENTO
      SET SALDO_RESTANTE = SALDO_RESTANTE - v_valor_soma
      WHERE ID_USUARIO   = v_id_usuario
      AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
      
      SELECT SUM(VALOR_POR_PAGAR)
      INTO v_valor_soma
      FROM DESPESAS
      WHERE ID_CATEGORIA   = 2
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE DESPESAS
      SET valor_pago    = valor_pago + valor_por_pagar, valor_por_pagar = 0
      WHERE ID_CATEGORIA   = 2
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE ORCAMENTO
      SET SALDO_RESTANTE = SALDO_RESTANTE - v_valor_soma
      WHERE ID_USUARIO   = v_id_usuario
      AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
      
      DBMS_OUTPUT.PUT_LINE('DESPESAS ESSENCIAIS E IMPORTANTES QUITADAS COM SUCESSO!');
    ELSIF verificar_despesas_importante() = 1 THEN 
      SELECT SUM(VALOR_POR_PAGAR)
      INTO v_valor_soma
      FROM DESPESAS
      WHERE ID_CATEGORIA   = 2
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE DESPESAS
      SET valor_pago    = valor_pago + valor_por_pagar, valor_por_pagar = 0
      WHERE ID_CATEGORIA   = 2
      AND STATUS_PAGAMENTO = 'pendente'
      AND ID_USUARIO = v_id_usuario;
      
      UPDATE ORCAMENTO
      SET SALDO_RESTANTE = SALDO_RESTANTE - v_valor_soma
      WHERE ID_USUARIO   = v_id_usuario
      AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
      
      DBMS_OUTPUT.PUT_LINE('PAGAMENTOS DAS DESPESAS IMPORTANTES QUITADAS COM SUCESSO!');
    END IF;
  END IF;
  
  UPDATE DESPESAS
  SET valor_pago = valor_pago + p_valor,
    valor_por_pagar = valor_por_pagar - p_valor
  WHERE ID_DESPESA  = p_despesa_id;
  
  UPDATE ORCAMENTO
  SET SALDO_RESTANTE = SALDO_RESTANTE - p_valor
  WHERE ID_USUARIO   = v_id_usuario
  AND mes_referencia = TO_CHAR(SYSDATE, 'MM/YYYY');
  
  DBMS_OUTPUT.PUT_LINE('PAGAMENTO EFETUADO COM SUCESSO!');
EXCEPTION
WHEN inserir_valor_negativo THEN
  RAISE_APPLICATION_ERROR(-20001, 'Valor de atualiza��o n�o pode ser negativo.');
WHEN inserir_valor_acima THEN
  RAISE_APPLICATION_ERROR(-20002, 'Saldo insuficiente para efetuar o pagamento');
WHEN efetuar_pagamento_quitado THEN
  RAISE_APPLICATION_ERROR(-20003, 'Imposs�vel efetuar o pagamento porque a despesa foi quitada');
WHEN inserir_pagamento_maior THEN
  RAISE_APPLICATION_ERROR(-20005, 'Valor inserido � maior que o valor a pagar');
END;
/

BEGIN
  --PAGAMENTO(3750,8);
  --COMMIT;
  relatorio_mensal();
END;
/