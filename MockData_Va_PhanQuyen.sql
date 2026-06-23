USE QuanLyDangKyHocPhan
GO

-- ============================================================
-- 1. NẠP DỮ LIỆU GIẢ LẬP (MOCK DATA) THEO 4 TẦNG
-- Tuân thủ nghiêm ngặt nguyên tắc bảo toàn thực thể 
-- ============================================================

-- TẦNG 1: Bảng độc lập
INSERT INTO TaiKhoan (TenDangNhap, MatKhauHash, VaiTro, TrangThai) VALUES 
('SV001', 'hash123', N'SinhVien', N'HoatDong'),
('SV002', 'hash123', N'SinhVien', N'HoatDong'),
('GV001', 'hash123', N'GiangVien', N'HoatDong');

INSERT INTO Khoa (MaKhoa, TenKhoa, LienHe) VALUES 
('CNTT', N'Công nghệ thông tin', N'0123456789');

INSERT INTO PhongHoc (MaPhong, TenPhong, ToaNha, SucChua) VALUES 
('A1-101', N'Phòng 101', N'Tòa A1', 50);

INSERT INTO HocKy (MaHK, TenHK, NamHoc, NgayBatDau, NgayKetThuc, TinChiToiThieu, TinChiToiDa) VALUES 
('HK1_2526', N'Học kỳ 1', 2025, '2025-09-05', '2026-01-15', 10, 25);

-- TẦNG 2: Bảng phụ thuộc cấp 1
INSERT INTO NganhHoc (MaNganh, TenNganh, MaKhoa) VALUES 
('KTPM', N'Kỹ thuật phần mềm', 'CNTT');

INSERT INTO GiangVien (MaGV, TenDangNhap, HoTen, Email, HocVi, MaKhoa) VALUES 
('GV001', 'GV001', N'Nguyễn Văn A', 'nva@truong.edu.vn', N'Tiến sĩ', 'CNTT');

INSERT INTO MonHoc (MaMon, TenMon, SoTinChi, MaKhoa) VALUES 
('CSDL', N'Cơ sở dữ liệu', 3, 'CNTT'),
('HTTT', N'Hệ thống thông tin', 3, 'CNTT');

-- Cố tình set thời gian đóng mở thật rộng để đảm bảo luôn test thành công
INSERT INTO DotDangKy (MaDot, MaHK, TenDot, KhoaTuyenSinhApDung, ThoiGianMo, ThoiGianDong) VALUES 
('DOT1', 'HK1_2526', N'Đợt 1 HK1', 'K2024', '2020-01-01', '2030-12-31');

-- TẦNG 3: Bảng phụ thuộc cấp 2
INSERT INTO SinhVien (MaSV, TenDangNhap, HoTen, NgaySinh, GioiTinh, Email, MaNganh, KhoaTuyenSinh, TrangThaiHocTap) VALUES 
('SV001', 'SV001', N'Ngô Gia Khánh', '2005-03-15', N'Nam', 'khanh@st.edu.vn', 'KTPM', 'K2024', N'DangHoc'),
('SV002', 'SV002', N'Trần Thị B', '2005-05-20', N'Nữ', 'ttb@st.edu.vn', 'KTPM', 'K2024', N'DangHoc');

-- Lớp CSDL_01 cố tình set sĩ số tối đa là 1 để test chức năng "Chặn lớp đầy"
INSERT INTO LopHocPhan (MaLHP, MaMon, MaHK, MaGV, SiSoToiDa, TrangThai) VALUES 
('CSDL_01', 'CSDL', 'HK1_2526', 'GV001', 1, N'DangMo'),
('HTTT_01', 'HTTT', 'HK1_2526', 'GV001', 40, N'DangMo');

-- Môn HTTT yêu cầu phải học CSDL trước
INSERT INTO DieuKienMonHoc (MaMon, MaMonYeuCau, LoaiDieuKien) VALUES 
('HTTT', 'CSDL', N'TienQuyet');

-- TẦNG 4: Bảng giao dịch
INSERT INTO ChiTietLichHoc (MaCTLH, MaLHP, Thu, TietBatDau, TietKetThuc, MaPhong) VALUES 
('LICH_CSDL1', 'CSDL_01', 3, 1, 3, 'A1-101');
INSERT INTO KetQuaHocTap (MaSV, MaMon, MaHK, TrangThaiQuaMon) 
VALUES ('SV001', 'CSDL', 'HK1_2526', N'KhongDat');
GO

-- ============================================================
-- 2. PHÂN QUYỀN BẢO MẬT (DCL) - Chống sinh viên sửa điểm
-- ============================================================
CREATE ROLE Role_SinhVien;
GRANT SELECT ON SCHEMA::dbo TO Role_SinhVien;
GRANT EXECUTE ON OBJECT::SP_DangKyHocPhan TO Role_SinhVien;

-- Tước quyền thao tác trên các bảng nhạy cảm
DENY INSERT, UPDATE, DELETE ON KetQuaHocTap TO Role_SinhVien;
DENY INSERT, UPDATE, DELETE ON LopHocPhan TO Role_SinhVien;
DENY UPDATE, DELETE ON SinhVien TO Role_SinhVien;
GO

-- ============================================================
-- 3. STORED PROCEDURE XUẤT BÁO CÁO THỜI KHÓA BIỂU
-- ============================================================
CREATE OR ALTER PROCEDURE SP_XuatThoiKhoaBieu
    @MaSV VARCHAR(20),
    @MaHK VARCHAR(10)
AS
BEGIN
    SELECT 
        lhp.MaLHP, m.TenMon, c.Thu, c.TietBatDau, c.TietKetThuc, p.TenPhong, gv.HoTen AS TenGiangVien
    FROM DangKyHocPhan dk
    JOIN LopHocPhan lhp ON dk.MaLHP = lhp.MaLHP
    JOIN MonHoc m ON lhp.MaMon = m.MaMon
    JOIN ChiTietLichHoc c ON lhp.MaLHP = c.MaLHP
    JOIN PhongHoc p ON c.MaPhong = p.MaPhong
    JOIN GiangVien gv ON lhp.MaGV = gv.MaGV
    WHERE dk.MaSV = @MaSV AND dk.TrangThaiDK = N'ThanhCong' AND lhp.MaHK = @MaHK
    ORDER BY c.Thu, c.TietBatDau;
END;
GO