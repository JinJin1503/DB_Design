USE QuanLyDangKyHocPhan
GO

-- ============================================================
-- PHẦN 1: TẠO INDEX TỐI ƯU TÌM KIẾM
-- ============================================================

CREATE INDEX IDX_DangKy_MaSV_TrangThai
ON DangKyHocPhan (MaSV, TrangThaiDK)
INCLUDE (MaLHP);
GO

CREATE INDEX IDX_DangKy_MaLHP_TrangThai
ON DangKyHocPhan (MaLHP, TrangThaiDK)
INCLUDE (MaSV);
GO

CREATE INDEX IDX_LopHocPhan_MaHK
ON LopHocPhan (MaHK)
INCLUDE (MaMon, MaGV, SiSoToiDa, TrangThai);
GO

CREATE INDEX IDX_LopHocPhan_MaMon_TrangThai
ON LopHocPhan (MaMon, TrangThai)
INCLUDE (MaHK, SiSoToiDa);
GO

CREATE INDEX IDX_LichHoc_MaLHP
ON ChiTietLichHoc (MaLHP)
INCLUDE (Thu, TietBatDau, TietKetThuc, MaPhong);
GO

CREATE INDEX IDX_LichHoc_Phong_Thu
ON ChiTietLichHoc (MaPhong, Thu, TietBatDau, TietKetThuc);
GO

CREATE INDEX IDX_KetQua_MaSV_MaMon_TrangThai
ON KetQuaHocTap (MaSV, MaMon, TrangThaiQuaMon);
GO

CREATE INDEX IDX_DotDangKy_MaHK_KhoaTuyenSinh
ON DotDangKy (MaHK, KhoaTuyenSinhApDung)
INCLUDE (ThoiGianMo, ThoiGianDong);
GO

CREATE INDEX IDX_DieuKien_MaMon_Loai
ON DieuKienMonHoc (MaMon, LoaiDieuKien)
INCLUDE (MaMonYeuCau);
GO


-- ============================================================
-- PHẦN 2: BẬT READ COMMITTED SNAPSHOT ISOLATION
-- ============================================================

ALTER DATABASE QuanLyDangKyHocPhan
SET READ_COMMITTED_SNAPSHOT ON;
GO


-- ============================================================
-- PHẦN 3: VÔ HIỆU HÓA CÁC TRIGGER CỦA THÀNH VIÊN 3
-- SP bên dưới đã kiểm tra đầy đủ TRƯỚC khi INSERT
-- => Trigger kiểm tra lại sau INSERT là dư thừa, kéo dài thời
--    gian giữ khóa HOLDLOCK, giảm hiệu suất khi tải cao.
-- ============================================================

DISABLE TRIGGER TRG_CheckSiSo       ON DangKyHocPhan;
GO
DISABLE TRIGGER TRG_CheckTienQuyet  ON DangKyHocPhan;
GO
DISABLE TRIGGER TRG_CheckTrungLich  ON DangKyHocPhan;
GO
DISABLE TRIGGER TRG_CheckDotDangKy  ON DangKyHocPhan;
GO
DISABLE TRIGGER TRG_CheckTinChiToiDa ON DangKyHocPhan;
GO


-- ============================================================
-- PHẦN 4: STORED PROCEDURE ĐĂNG KÝ HỌC PHẦN
-- ============================================================

CREATE OR ALTER PROCEDURE SP_DangKyHocPhan
    @MaSV      VARCHAR(20),
    @MaLHP     VARCHAR(30),
    @KetQua    INT OUTPUT,      -- 0 = thành công, 1 = thất bại
    @ThongBao  NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Không dùng DEADLOCK_PRIORITY LOW:
    -- Không có tiến trình nào quan trọng hơn giao dịch đăng ký
    -- của sinh viên => giữ mức Normal mặc định.

    DECLARE @MaHK         VARCHAR(10);
    DECLARE @MaMon        VARCHAR(20);
    DECLARE @SiSoToiDa    INT;
    DECLARE @SiSoHienTai  INT;
    DECLARE @TongTinChi   INT;
    DECLARE @TinChiToiDa  INT;
    DECLARE @TinChiMonMoi INT;

    SET @KetQua   = 1;
    SET @ThongBao = N'';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Khóa dòng LopHocPhan: UPDLOCK + ROWLOCK + HOLDLOCK
        -- Đảm bảo chỉ 1 transaction kiểm tra + ghi sĩ số cùng lúc
        -- cho lớp này. Các lớp khác nhau không chặn nhau (ROWLOCK).
        SELECT
            @MaHK      = MaHK,
            @MaMon     = MaMon,
            @SiSoToiDa = SiSoToiDa
        FROM LopHocPhan WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE MaLHP    = @MaLHP
          AND TrangThai = N'DangMo';

        IF @MaHK IS NULL
        BEGIN
            SET @ThongBao = N'Lớp học phần không tồn tại hoặc đã đóng.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM DotDangKy d
            JOIN SinhVien  sv ON sv.MaSV = @MaSV
            WHERE d.MaHK = @MaHK
              AND GETDATE() BETWEEN d.ThoiGianMo AND d.ThoiGianDong
              AND d.KhoaTuyenSinhApDung = sv.KhoaTuyenSinh
        )
        BEGIN
            SET @ThongBao = N'Hiện không nằm trong đợt đăng ký hợp lệ.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM DieuKienMonHoc dk
            WHERE dk.MaMon        = @MaMon
              AND dk.LoaiDieuKien = N'TienQuyet'
              AND NOT EXISTS (
                  SELECT 1
                  FROM KetQuaHocTap kq
                  WHERE kq.MaSV            = @MaSV
                    AND kq.MaMon           = dk.MaMonYeuCau
                    AND kq.TrangThaiQuaMon = N'Dat'
              )
        )
        BEGIN
            SET @ThongBao = N'Chưa đạt môn tiên quyết.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT @SiSoHienTai = COUNT(*)
        FROM DangKyHocPhan
        WHERE MaLHP       = @MaLHP
          AND TrangThaiDK = N'ThanhCong';

        IF @SiSoHienTai >= @SiSoToiDa
        BEGIN
            SET @ThongBao = N'Lớp học phần đã đầy.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM ChiTietLichHoc  lichMoi
            JOIN DangKyHocPhan   dkCu   ON dkCu.MaSV        = @MaSV
                                        AND dkCu.TrangThaiDK = N'ThanhCong'
                                        AND dkCu.MaLHP      <> @MaLHP
            JOIN ChiTietLichHoc  lichCu ON lichCu.MaLHP      = dkCu.MaLHP
            WHERE lichMoi.MaLHP        = @MaLHP
              AND lichMoi.Thu          = lichCu.Thu
              AND lichMoi.TietBatDau  <= lichCu.TietKetThuc
              AND lichMoi.TietKetThuc >= lichCu.TietBatDau
        )
        BEGIN
            SET @ThongBao = N'Trùng lịch học với lớp đã đăng ký.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT @TinChiToiDa  = TinChiToiDa
        FROM   HocKy
        WHERE  MaHK = @MaHK;

        SELECT @TinChiMonMoi = SoTinChi
        FROM   MonHoc
        WHERE  MaMon = @MaMon;

        SELECT @TongTinChi = ISNULL(SUM(m.SoTinChi), 0)
        FROM DangKyHocPhan dk
        JOIN LopHocPhan    lhp ON dk.MaLHP  = lhp.MaLHP
        JOIN MonHoc        m   ON lhp.MaMon = m.MaMon
        WHERE dk.MaSV        = @MaSV
          AND dk.TrangThaiDK = N'ThanhCong'
          AND lhp.MaHK       = @MaHK;

        IF (@TongTinChi + @TinChiMonMoi) > @TinChiToiDa
        BEGIN
            SET @ThongBao = N'Vượt quá số tín chỉ tối đa cho phép.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO DangKyHocPhan (MaSV, MaLHP, ThoiGianDK, TrangThaiDK)
        VALUES (@MaSV, @MaLHP, GETDATE(), N'ThanhCong');

        COMMIT TRANSACTION;
        SET @KetQua   = 0;
        SET @ThongBao = N'Đăng ký học phần thành công.';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @KetQua   = 1;
        SET @ThongBao = ERROR_MESSAGE();
    END CATCH
END
GO


-- ============================================================
-- PHẦN 5: STORED PROCEDURE HỦY ĐĂNG KÝ HỌC PHẦN
-- ============================================================

CREATE OR ALTER PROCEDURE SP_HuyDangKy
    @MaSV     VARCHAR(20),
    @MaLHP    VARCHAR(30),
    @KetQua   INT OUTPUT,
    @ThongBao NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @KetQua   = 1;
    SET @ThongBao = N'';

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM DangKyHocPhan WITH (UPDLOCK, ROWLOCK)
            WHERE MaSV        = @MaSV
              AND MaLHP       = @MaLHP
              AND TrangThaiDK = N'ThanhCong'
        )
        BEGIN
            SET @ThongBao = N'Không tìm thấy đăng ký hợp lệ để hủy.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE DangKyHocPhan
        SET    TrangThaiDK = N'DaHuy'
        WHERE  MaSV        = @MaSV
          AND  MaLHP       = @MaLHP
          AND  TrangThaiDK = N'ThanhCong';

        COMMIT TRANSACTION;
        SET @KetQua   = 0;
        SET @ThongBao = N'Hủy đăng ký thành công.';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @KetQua   = 1;
        SET @ThongBao = ERROR_MESSAGE();
    END CATCH
END
GO
