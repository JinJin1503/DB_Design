USE QuanLyDangKyHocPhan
GO

CREATE TRIGGER TRG_CheckSiSo
ON DangKyHocPhan
AFTER INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN LopHocPhan lhp
            ON i.MaLHP = lhp.MaLHP
        WHERE
        (
            SELECT COUNT(*)
            FROM DangKyHocPhan dk
            WHERE dk.MaLHP = i.MaLHP
              AND dk.TrangThaiDK = N'ThanhCong'
        ) > lhp.SiSoToiDa
    )
    BEGIN
        RAISERROR(N'Lớp học phần đã đầy.',16,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

CREATE TRIGGER TRG_CheckTienQuyet
ON DangKyHocPhan
AFTER INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN LopHocPhan lhp
            ON i.MaLHP = lhp.MaLHP
        JOIN DieuKienMonHoc dk
            ON dk.MaMon = lhp.MaMon
           AND dk.LoaiDieuKien = N'TienQuyet'
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM KetQuaHocTap kq
            WHERE kq.MaSV = i.MaSV
              AND kq.MaMon = dk.MaMonYeuCau
              AND kq.TrangThaiQuaMon = N'Dat'
        )
    )
    BEGIN
        RAISERROR(N'Chưa đạt môn tiên quyết.',16,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

CREATE TRIGGER TRG_CheckTrungLich
ON DangKyHocPhan
AFTER INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN ChiTietLichHoc lichMoi
            ON lichMoi.MaLHP = i.MaLHP
        JOIN DangKyHocPhan dk
            ON dk.MaSV = i.MaSV
           AND dk.MaLHP <> i.MaLHP
           AND dk.TrangThaiDK = N'ThanhCong'
        JOIN ChiTietLichHoc lichCu
            ON lichCu.MaLHP = dk.MaLHP
        WHERE lichMoi.Thu = lichCu.Thu
          AND lichMoi.TietBatDau <= lichCu.TietKetThuc
          AND lichMoi.TietKetThuc >= lichCu.TietBatDau
    )
    BEGIN
        RAISERROR(N'Trùng lịch học với lớp đã đăng ký.',16,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

CREATE TRIGGER TRG_CheckDotDangKy
ON DangKyHocPhan
AFTER INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN SinhVien sv
            ON sv.MaSV = i.MaSV
        JOIN LopHocPhan lhp
            ON lhp.MaLHP = i.MaLHP
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM DotDangKy d
            WHERE d.MaHK = lhp.MaHK
              AND GETDATE() BETWEEN d.ThoiGianMo AND d.ThoiGianDong
              AND d.KhoaTuyenSinhApDung = sv.KhoaTuyenSinh
        )
    )
    BEGIN
        RAISERROR(N'Hiện không nằm trong đợt đăng ký hợp lệ.',16,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

CREATE TRIGGER TRG_CheckTinChiToiDa
ON DangKyHocPhan
AFTER INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN LopHocPhan lhpMoi
            ON lhpMoi.MaLHP = i.MaLHP
        JOIN HocKy hk
            ON hk.MaHK = lhpMoi.MaHK
        WHERE
        (
            SELECT SUM(m.SoTinChi)
            FROM DangKyHocPhan dk
            JOIN LopHocPhan lhp
                ON dk.MaLHP = lhp.MaLHP
            JOIN MonHoc m
                ON m.MaMon = lhp.MaMon
            WHERE dk.MaSV = i.MaSV
              AND dk.TrangThaiDK = N'ThanhCong'
              AND lhp.MaHK = lhpMoi.MaHK
        ) > hk.TinChiToiDa
    )
    BEGIN
        RAISERROR(N'Vượt quá số tín chỉ tối đa cho phép.',16,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO