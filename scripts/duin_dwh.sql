-- ============================================================================
-- SCRIPT DE CRÉATION DU DATA WAREHOUSE DUNIN_DWH
-- Version: 1.0
-- Description: Création complète de la base de données dimensionnelle
-- Auteur: ETL Team
-- Date: 2025
-- ============================================================================

-- Création de la base de données
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DUNIN_DWH')
BEGIN
    CREATE DATABASE DUNIN_DWH;
    PRINT 'Base de données DUNIN_DWH créée avec succès.';
END
ELSE
BEGIN
    PRINT 'Base de données DUNIN_DWH existe déjà.';
END
GO

USE DUNIN_DWH;
GO

-- ============================================================================
-- SUPPRESSION DES TABLES EXISTANTES (pour réinitialisation complète)
-- ============================================================================

-- Suppression des tables de faits (dépendantes)
IF OBJECT_ID('dbo.fact_etapes', 'U') IS NOT NULL DROP TABLE dbo.fact_etapes;
IF OBJECT_ID('dbo.fact_lumieres', 'U') IS NOT NULL DROP TABLE dbo.fact_lumieres;
IF OBJECT_ID('dbo.fact_kits', 'U') IS NOT NULL DROP TABLE dbo.fact_kits;
IF OBJECT_ID('dbo.transactions', 'U') IS NOT NULL DROP TABLE dbo.transactions;

-- Suppression des tables de dimensions
IF OBJECT_ID('dbo.dim_clients', 'U') IS NOT NULL DROP TABLE dbo.dim_clients;
IF OBJECT_ID('dbo.dim_representants', 'U') IS NOT NULL DROP TABLE dbo.dim_representants;
IF OBJECT_ID('dbo.dim_adresses', 'U') IS NOT NULL DROP TABLE dbo.dim_adresses;
IF OBJECT_ID('dbo.dim_projets', 'U') IS NOT NULL DROP TABLE dbo.dim_projets;
IF OBJECT_ID('dbo.dim_dates', 'U') IS NOT NULL DROP TABLE dbo.dim_dates;

PRINT 'Tables existantes supprimées.';
GO

-- ============================================================================
-- CRÉATION DES TABLES DE DIMENSIONS
-- ============================================================================

-- -----------------------------
-- DIMENSION DATES
-- -----------------------------
CREATE TABLE dbo.dim_dates (
    date_id         INT PRIMARY KEY,
    date            DATE NOT NULL,
    annee           INT NOT NULL,
    mois            INT NOT NULL,
    nom_mois        NVARCHAR(20) NOT NULL,
    jour            INT NOT NULL,
    jour_semaine    INT NOT NULL,
    nom_jour        NVARCHAR(20) NOT NULL,
    
);


-- -----------------------------
-- DIMENSION CLIENTS
-- -----------------------------
CREATE TABLE dbo.dim_clients (
    client_id       INT IDENTITY(1,1) PRIMARY KEY,
    nom             NVARCHAR(255) NULL,
    type            NVARCHAR(100) NULL,
    transaction_id  NVARCHAR(50) NULL,
);

PRINT 'Table dim_clients créée.';

-- -----------------------------
-- DIMENSION PROJETS
-- -----------------------------
CREATE TABLE dbo.dim_projets (
    projet_id           NVARCHAR(50) PRIMARY KEY,
    marche              NVARCHAR(100) NULL,
    division            NVARCHAR(100) NULL,
    courrielContact     NVARCHAR(255) NULL,
    nomContact          NVARCHAR(255) NULL,
    telephoneContact    NVARCHAR(50) NULL,
    coordsCommTxt       NVARCHAR(500) NULL,
    coordsExpedTxt      NVARCHAR(500) NULL,
    coordsFactTxt       NVARCHAR(500) NULL,
    estReprise          BIT DEFAULT 0,
    enFusion            BIT DEFAULT 0,
    createurNom         NVARCHAR(255) NULL,
    createurCourriel    NVARCHAR(255) NULL,
);


-- -----------------------------
-- DIMENSION REPRESENTANTS
-- -----------------------------
CREATE TABLE dbo.dim_representants (
    representant_id     INT IDENTITY(1,1) PRIMARY KEY,
    nom                 NVARCHAR(255) NULL,
    codeRepresentant    NVARCHAR(50) NULL,
    projet_id           NVARCHAR(50) NULL,
    -- Clé étrangère
    CONSTRAINT FK_dim_representants_projet 
        FOREIGN KEY (projet_id) REFERENCES dbo.dim_projets(projet_id)
);

PRINT 'Table dim_representants créée.';

-- -----------------------------
-- DIMENSION ADRESSES
-- -----------------------------
CREATE TABLE dbo.dim_adresses (
    adresse_id      INT IDENTITY(1,1) PRIMARY KEY,
    codePost        NVARCHAR(20) NULL,
    etatProv        NVARCHAR(100) NULL,
    ligne1          NVARCHAR(500) NULL,
    ligne2          NVARCHAR(500) NULL,
    pays            NVARCHAR(100) NULL,
    region          NVARCHAR(100) NULL,
    ville           NVARCHAR(100) NULL,
    usage           NVARCHAR(50) NULL,
    code            NVARCHAR(50) NULL,
    sorte           NVARCHAR(50) NULL,
    projet_id       NVARCHAR(50) NULL,
    nom             NVARCHAR(255) NULL,
    contact         NVARCHAR(255) NULL,
    
    -- Clé étrangère
    CONSTRAINT FK_dim_adresses_projet 
        FOREIGN KEY (projet_id) REFERENCES dbo.dim_projets(projet_id)
);

-- ============================================================================
-- CRÉATION DE LA TABLE DE FAIT PRINCIPALE
-- ============================================================================

-- -----------------------------
-- TRANSACTIONS (Fait principal)
-- -----------------------------
CREATE TABLE dbo.transactions (
    transaction_id          NVARCHAR(50) PRIMARY KEY,
    
    -- Clés étrangères vers dimensions
    projet_id               NVARCHAR(50) NULL,
    date_creation_id        INT NULL,
    date_validite_id        INT NULL,
    date_prev_exped_id      INT NULL,
    
    -- Informations client (dénormalisé pour performance)
    nomClient               NVARCHAR(255) NULL,
    codeClient2             NVARCHAR(50) NULL,
    typeClient              NVARCHAR(100) NULL,
    
    -- Métriques temporelles
    delaiPrevExped          DECIMAL(10,2) NULL,
    nbJourValide            DECIMAL(10,2) NULL,
    
    -- Statuts et indicateurs
    statutCred              BIT DEFAULT 0,
    validCred               BIT DEFAULT 0,
    estImport               BIT DEFAULT 0,
    estReprise              BIT DEFAULT 0,
    estCQ                   BIT DEFAULT 0,
    avecLivraison           BIT DEFAULT 0,
    installation            BIT DEFAULT 0,
    psd                     BIT DEFAULT 0,
    
    -- Métriques financières principales
    total                   DECIMAL(15,2) NULL,
    totalHT                 DECIMAL(15,2) NULL,
    sousTotal               DECIMAL(15,2) NULL,
    sousTotal2              DECIMAL(15,2) NULL,
    
    -- Métriques de services
    totalLivraison          DECIMAL(15,2) NULL,
    totalInstall            DECIMAL(15,2) NULL,
    totalCEM                DECIMAL(15,2) NULL,
    
    -- Métriques de quantité
    qteItems                DECIMAL(10,2) NULL,
    qteItemsCab             DECIMAL(10,2) NULL,
    promotions              DECIMAL(15,2) NULL,
    
    -- Informations création
    createurNom             NVARCHAR(255) NULL,
    createurCourriel        NVARCHAR(255) NULL,
    division                NVARCHAR(100) NULL,
    
    -- Taxes et ajustements
    totalTx1                DECIMAL(15,2) NULL,
    totalTx2                DECIMAL(15,2) NULL,
    ecartPrix               DECIMAL(15,2) NULL,
    solde                   DECIMAL(15,2) NULL,
    
    -- Spécificités contrats (comptoirs)
    totalComptoirBois       DECIMAL(15,2) NULL,
    totalComptoirGranite    DECIMAL(15,2) NULL,
    totalComptoirQuartz     DECIMAL(15,2) NULL,
    totalComptoirStratifie  DECIMAL(15,2) NULL,
    totalEsc                DECIMAL(15,2) NULL,
    montantEcartPrix        DECIMAL(15,2) NULL,
    
    -- Frais spécialisés
    fraisPSD                DECIMAL(15,2) NULL,
    fraisPDM                DECIMAL(15,2) NULL,
    fraisSAV                DECIMAL(15,2) NULL,
    TotalEscompte           DECIMAL(15,2) NULL,
    
    -- Codes postaux
    codePost                NVARCHAR(20) NULL,
    codePostFinal           NVARCHAR(20) NULL,
    
  
   
    -- Clés étrangères
    CONSTRAINT FK_transactions_projet 
        FOREIGN KEY (projet_id) REFERENCES dbo.dim_projets(projet_id),
    CONSTRAINT FK_transactions_date_creation 
        FOREIGN KEY (date_creation_id) REFERENCES dbo.dim_dates(date_id),
    CONSTRAINT FK_transactions_date_validite 
        FOREIGN KEY (date_validite_id) REFERENCES dbo.dim_dates(date_id),
    CONSTRAINT FK_transactions_date_exped 
        FOREIGN KEY (date_prev_exped_id) REFERENCES dbo.dim_dates(date_id)
);


-- ============================================================================
-- CRÉATION DES TABLES DE FAITS SECONDAIRES
-- ============================================================================

-- -----------------------------
-- FACT_ETAPES
-- -----------------------------
CREATE TABLE dbo.fact_etapes (
    etape_id        INT IDENTITY(1,1) PRIMARY KEY,
    createur        NVARCHAR(255) NULL,
    emplacement     NVARCHAR(255) NULL,
    statut          NVARCHAR(100) NULL,
    tempsCreation   DECIMAL(10,2) NULL,
    commande_id     NVARCHAR(50) NULL,
    contrat_id      NVARCHAR(50) NULL,
    

);

-- -----------------------------
-- FACT_LUMIERES
-- -----------------------------
CREATE TABLE dbo.fact_lumieres (
    lumiere_id      INT IDENTITY(1,1) PRIMARY KEY,
    modele          NVARCHAR(255) NULL,
    qte             DECIMAL(10,2) NULL,
    contrat_id      NVARCHAR(50) NULL,
    
);

-- -----------------------------
-- FACT_KITS (Table la plus complexe)
-- -----------------------------
CREATE TABLE dbo.fact_kits (
    kit_id                      INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Identification
    code                        NVARCHAR(50) NULL,
    nom                         NVARCHAR(255) NULL,
    typeKit                     NVARCHAR(100) NULL,
    unit                        NVARCHAR(50) NULL,
    ligne                       NVARCHAR(50) NULL,
    
    -- Liens transactionnels
    commande_id                 NVARCHAR(50) NULL,
    contrat_id                  NVARCHAR(50) NULL,
    
    -- Quantités
    qte                         DECIMAL(10,2) NULL,
    qteTr                       DECIMAL(10,2) NULL,
    
    -- Métriques financières
    sousTotalKit                DECIMAL(15,2) NULL,
    sousTotalKitEff             DECIMAL(15,2) NULL,
    sousTotal                   DECIMAL(15,2) NULL,
    sousTotalEff                DECIMAL(15,2) NULL,
    sousTotalCab                DECIMAL(15,2) NULL,
    sousTotalPanel              DECIMAL(15,2) NULL,
    sousTotalMoulure            DECIMAL(15,2) NULL,
    sousTotalAutre              DECIMAL(15,2) NULL,
    
    -- Comptoirs
    totalComptoir               DECIMAL(15,2) NULL,
    totalComptoirEff            DECIMAL(15,2) NULL,
    nbComptoir                  DECIMAL(10,2) NULL,
    longComptoir                DECIMAL(10,2) NULL,
    surfaceComptoir             DECIMAL(10,2) NULL,
    cumulComptoir               DECIMAL(10,2) NULL,
    extraComptoir               DECIMAL(15,2) NULL,
    comptoirMod                 NVARCHAR(100) NULL,
    comptoirCouleur             NVARCHAR(100) NULL,
    comptoirGpCouleur           NVARCHAR(100) NULL,
    
    -- Caractéristiques produit
    assemblage                  NVARCHAR(100) NULL,
    gamme                       NVARCHAR(100) NULL,
    serie                       NVARCHAR(100) NULL,
    finishColor                 NVARCHAR(100) NULL,
    specie                      NVARCHAR(100) NULL,
    
    -- Bordures et finitions
    edgeColle                   NVARCHAR(100) NULL,
    edgeBanding                 NVARCHAR(100) NULL,
    bd_edgeBanding              NVARCHAR(100) NULL,
    df_edgeBanding              NVARCHAR(100) NULL,
    wd_edgeBanding              NVARCHAR(100) NULL,
    edgePorte                   NVARCHAR(100) NULL,
    edgeTablette                NVARCHAR(100) NULL,
    
    -- Poignées
    handle                      NVARCHAR(100) NULL,
    handleOri                   NVARCHAR(100) NULL,
    bd_handle                   NVARCHAR(100) NULL,
    bd_handleOri                NVARCHAR(100) NULL,
    df_handle                   NVARCHAR(100) NULL,
    df_handleOri                NVARCHAR(100) NULL,
    
    -- Configuration armoires
    cabDesign                   NVARCHAR(100) NULL,
    cabConstruct                NVARCHAR(100) NULL,
    cabHinge                    NVARCHAR(100) NULL,
    cabWallProf                 DECIMAL(10,2) NULL,
    t_cabWallProf               NVARCHAR(50) NULL,
    cabHautComptoir             DECIMAL(10,2) NULL,
    t_cabHautComptoir           NVARCHAR(50) NULL,
    cabDegagementWall           DECIMAL(10,2) NULL,
    t_cabDegagementWall         NVARCHAR(50) NULL,
    cabToeKickHeight            DECIMAL(10,2) NULL,
    t_cabToeKickHeight          NVARCHAR(50) NULL,
    cabToeKickProf              DECIMAL(10,2) NULL,
    t_cabToeKickProf            NVARCHAR(50) NULL,
    cabToeKickType              NVARCHAR(100) NULL,
    cabAlignBase                NVARCHAR(100) NULL,
    t_cabAlignBase              NVARCHAR(50) NULL,
    cabTallHeightAlign          NVARCHAR(100) NULL,
    t_cabTallHeightAlign        NVARCHAR(50) NULL,
    cabTypeComptoir             NVARCHAR(100) NULL,
    
    -- Éléments techniques
    tabletteType                NVARCHAR(100) NULL,
    drawerConst                 NVARCHAR(100) NULL,
    drawerSlide                 NVARCHAR(100) NULL,
    matPatte                    NVARCHAR(100) NULL,
    patteAchetee                NVARCHAR(100) NULL,
    equerre                     NVARCHAR(100) NULL,
    cacheNeon                   NVARCHAR(100) NULL,
    
    -- Poutres
    beamModele                  NVARCHAR(100) NULL,
    beamHeight                  DECIMAL(10,2) NULL,
    t_beamHeight                NVARCHAR(50) NULL,
    
    -- Indicateurs
    estBloqPrix                 BIT DEFAULT 0,
    estPrixAdmin                BIT DEFAULT 0,
    estExtra                    BIT DEFAULT 0,
    enErreur                    BIT DEFAULT 0,
    psd                         BIT DEFAULT 0,
    
    -- Signatures et utilisation
    signature                   NVARCHAR(255) NULL,
    kitUtilisation              NVARCHAR(255) NULL,
    
    -- Spécifications matériaux détaillées
    bd_specie                   NVARCHAR(100) NULL,
    df_specie                   NVARCHAR(100) NULL,
    bd_serie                    NVARCHAR(100) NULL,
    df_serie                    NVARCHAR(100) NULL,
    bd_finishColor              NVARCHAR(100) NULL,
    df_finishColor              NVARCHAR(100) NULL,
    
    -- Modèles de portes
    porteModeleB                NVARCHAR(100) NULL,
    porteModeleH                NVARCHAR(100) NULL,
    porteModeleFacadeB          NVARCHAR(100) NULL,
    porteModeleFacadeH          NVARCHAR(100) NULL,
    porteModeleBSensGrain       NVARCHAR(100) NULL,
    porteModeleHSensGrain       NVARCHAR(100) NULL,
    porteModeleFacadeBSensGrain NVARCHAR(100) NULL,
    porteModeleFacadeHSensGrain NVARCHAR(100) NULL,
    
    -- Épaisseurs portes
    porteModeleB_epais          DECIMAL(10,2) NULL,
    t_porteModeleB_epais        NVARCHAR(50) NULL,
    porteModeleH_epais          DECIMAL(10,2) NULL,
    t_porteModeleH_epais        NVARCHAR(50) NULL,
    porteModeleFacadeB_epais    DECIMAL(10,2) NULL,
    t_porteModeleFacadeB_epais  NVARCHAR(50) NULL,
    porteModeleFacadeH_epais    DECIMAL(10,2) NULL,
    t_porteModeleFacadeH_epais  NVARCHAR(50) NULL,
    
    -- Moulures
    moulLumModele               NVARCHAR(100) NULL,
    moulLumHeight               DECIMAL(10,2) NULL,
    t_moulLumHeight             NVARCHAR(50) NULL,
    moulPiedModele              NVARCHAR(100) NULL,
    moulPiedHeight              DECIMAL(10,2) NULL,
    t_moulPiedHeight            NVARCHAR(50) NULL,
    
    -- Détails techniques
    detailSection               NVARCHAR(255) NULL,
    aBomCustom                  NVARCHAR(255) NULL,
    couleurEstBois              NVARCHAR(100) NULL,
    items                       NTEXT NULL,
    typeColor                   NVARCHAR(100) NULL,
    
 
);

  
GO